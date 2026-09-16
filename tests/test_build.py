import json
import os
import shutil
import subprocess
import tempfile
import unittest
from contextlib import ExitStack
from html.parser import HTMLParser
from pathlib import Path
from unittest.mock import patch

import build
from build_cache import BuildCache, snapshot_inputs, validate_metadata


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = '#import "/tufted-lib/tufted.typ": tufted-web\n'


class Head(HTMLParser):
    def __init__(self):
        super().__init__()
        self.title = ""
        self.in_title = False
        self.meta = {}

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.in_title |= tag == "title"
        if tag == "meta":
            self.meta[attrs.get("name", attrs.get("property"))] = attrs.get("content")

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.title += data


@unittest.skipUnless(shutil.which("typst"), "Typst is required")
class BuildIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.root = Path(self.stack.enter_context(tempfile.TemporaryDirectory(dir=ROOT)))
        self.content = self.root / "content"
        self.site = self.root / "_site"
        self.content.mkdir()
        self.stack.enter_context(patch.object(build, "CONTENT_DIR", self.content))
        self.stack.enter_context(patch.object(build, "SITE_DIR", self.site))
        self.stack.enter_context(patch.object(build, "build_signature", return_value={"test": 1}))

    def page(self, text, path="index.typ"):
        source = self.content / path
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_text(TEMPLATE + text, encoding="utf-8")
        return source

    def compile(self, sources, force=False):
        return build._compile_files(sources, force, "html")

    def test_real_dependencies_hashes_and_atomic_failure_recovery(self):
        source = self.page('''#show: tufted-web.with(title: [Cache])
#let module-path = "_helper.typ"
#import module-path: data
#read(data)
''')
        helper = self.content / "_helper.typ"
        helper.write_text('#let data = "nested/message.txt"')
        asset = self.content / "nested/message.txt"
        asset.parent.mkdir()
        asset.write_text("before")
        output = self.site / "index.html"
        self.assertEqual(self.compile([source]).success, 1)
        self.assertEqual(self.compile([source]).skipped, 1)
        stamp = asset.stat()
        asset.write_text("after!")
        os.utime(asset, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
        self.assertEqual(self.compile([source]).success, 1)
        self.assertIn("after!", output.read_text())
        previous = output.read_bytes()
        asset.unlink()
        self.assertEqual(self.compile([source]).failed, 1)
        self.assertEqual(output.read_bytes(), previous)
        self.assertEqual(self.compile([source]).failed, 1)
        asset.write_text("restored")
        self.assertEqual(self.compile([source]).success, 1)
        previous = output.read_bytes()
        with patch.object(build, "evaluate_page_metadata", side_effect=ValueError("invalid metadata")):
            self.assertEqual(self.compile([source], force=True).failed, 1)
        self.assertEqual(output.read_bytes(), previous)
        output.write_text("corrupted")
        self.assertEqual(self.compile([source]).success, 1)

    def test_dynamic_metadata_and_deleted_outputs(self):
        source = self.page('''#let section = "Blog"
#show: tufted-web.with(title: [A *rich* `title`],
  website-url: "https://example.com/", feed-dir: ("/" + section + "/",))
#title()
''')
        self.assertEqual(self.compile([source]).success, 1)
        data = build.load_page_metadata(self.site / "index.html")
        self.assertEqual(data["feed-dirs"], ["/Blog/"])
        self.assertEqual(data["title"], "A rich title")
        self.assertEqual(data["link"], "https://example.com/")
        source.unlink()
        self.assertFalse(self.compile([]).has_failures)
        self.assertFalse((self.site / "index.html").exists())

    def test_source_saved_between_compile_and_eval_is_retried(self):
        original = '#show: tufted-web.with(title: [Old title])\nOld body'
        updated = '#show: tufted-web.with(title: [New title])\nNew body'
        source = self.page(original)
        self.assertEqual(self.compile([source]).success, 1)
        evaluate = build.evaluate_page_metadata
        changed = False

        def save_then_evaluate(path):
            nonlocal changed
            if not changed:
                source.write_text(TEMPLATE + updated)
                changed = True
            return evaluate(path)

        with (
            patch.object(build, "evaluate_page_metadata", side_effect=save_then_evaluate),
            patch.object(build, "run_typst_command", wraps=build.run_typst_command) as compiler,
        ):
            self.assertEqual(self.compile([source], force=True).success, 1)
            self.assertEqual(compiler.call_count, 2)
        output = self.site / "index.html"
        self.assertIn("New body", output.read_text())
        self.assertNotIn("Old body", output.read_text())
        self.assertEqual(build.load_page_metadata(output)["title"], "New title")
        self.assertEqual(self.compile([source]).skipped, 1)

    def test_new_dependency_changed_during_cold_compile_is_retried(self):
        source = self.page('#show: tufted-web.with(title: [Dependency])\n#read("_data.txt")')
        dependency = self.content / "_data.txt"
        dependency.write_text("before")
        command = build.run_typst_command
        calls = 0

        def compile_then_save(args):
            nonlocal calls
            result = command(args)
            calls += 1
            if calls == 1:
                stamp = dependency.stat()
                dependency.write_text("after!")
                os.utime(dependency, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
            return result

        with patch.object(build, "run_typst_command", side_effect=compile_then_save):
            self.assertEqual(self.compile([source]).success, 1)
        self.assertEqual(calls, 2)
        self.assertIn("after!", (self.site / "index.html").read_text())
        self.assertEqual(self.compile([source]).skipped, 1)

    def test_save_and_restore_during_eval_is_detected(self):
        source = self.page('#show: tufted-web.with(title: [Original])\nBody')
        self.assertEqual(self.compile([source]).success, 1)
        original = source.read_text()
        stamp = source.stat()
        evaluate = build.evaluate_page_metadata
        calls = 0

        def evaluate_transient_source(path):
            nonlocal calls
            calls += 1
            if calls != 1:
                return evaluate(path)
            source.write_text(original.replace("Original", "Transient"))
            metadata = evaluate(path)
            source.write_text(original)
            os.utime(source, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
            return metadata

        with patch.object(build, "evaluate_page_metadata", side_effect=evaluate_transient_source):
            self.assertEqual(self.compile([source], force=True).success, 1)
        self.assertEqual(calls, 2)
        self.assertEqual(build.load_page_metadata(self.site / "index.html")["title"], "Original")

    def test_continuous_edits_preserve_previous_output_and_cache(self):
        source = self.page('#show: tufted-web.with(title: [Stable])\nStable body')
        self.assertEqual(self.compile([source]).success, 1)
        output = self.site / "index.html"
        cache = BuildCache(build.cache_directory(), {"test": 1})
        previous_output = output.read_bytes()
        previous_record = cache.record_path(output).read_bytes()
        evaluate = build.evaluate_page_metadata
        calls = 0

        def edit_each_time(path):
            nonlocal calls
            calls += 1
            source.write_text(TEMPLATE + f'#show: tufted-web.with(title: [Edit {calls}])\nBody {calls}')
            return evaluate(path)

        with patch.object(build, "evaluate_page_metadata", side_effect=edit_each_time):
            self.assertEqual(self.compile([source], force=True).failed, 1)
        self.assertEqual(calls, 3)
        self.assertEqual(output.read_bytes(), previous_output)
        self.assertEqual(cache.record_path(output).read_bytes(), previous_record)
        self.assertEqual(self.compile([source]).success, 1)
        self.assertEqual(build.load_page_metadata(output)["title"], "Edit 3")
        self.assertEqual(self.compile([source]).skipped, 1)

    def test_rich_metadata_matches_native_typst_head(self):
        title = '[A *bold* _italic_ `raw` #link("https://example.com")[link] $x^2$ & < > "quote"]'
        source = self.page(f'#show: tufted-web.with(title: {title}, description: {title})\n#title()')
        self.assertEqual(self.compile([source]).success, 1)
        modern = Head()
        modern.feed((self.site / "index.html").read_text())
        result = subprocess.run(
            ["typst", "compile", "--features", "html", "--format", "html", "-", "-"],
            input=f"#set document(title: {title}, description: {title})\nNative",
            capture_output=True, text=True, check=True,
        )
        native = Head()
        native.feed(result.stdout)
        self.assertEqual(modern.title, native.title)
        self.assertEqual(modern.meta["description"], native.meta["description"])
        self.assertEqual(modern.meta["og:title"], native.title)

    def test_document_keywords_and_multiple_authors(self):
        source = self.page('''#set document(keywords: ("a", "b"))
#show: tufted-web.with(title: [Changed *title*], author: ("One", "Two"))
#title()
''')
        self.assertEqual(self.compile([source]).success, 1)
        parsed = Head()
        parsed.feed((self.site / "index.html").read_text())
        self.assertEqual(parsed.title, "Changed title")
        self.assertEqual(parsed.meta["authors"], "One, Two")
        self.assertEqual(parsed.meta["keywords"], "a, b")
        self.assertEqual(build.load_page_metadata(self.site / "index.html")["title"], parsed.title)

    def test_assets_removed_and_backdated_changes(self):
        asset = self.content / "file.txt"
        asset.write_text("first")
        self.assertTrue(build.copy_content_assets())
        stamp = asset.stat()
        asset.write_text("other")
        os.utime(asset, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
        self.assertTrue(build.copy_content_assets())
        self.assertEqual((self.site / "file.txt").read_text(), "other")
        asset.unlink()
        self.assertTrue(build.copy_content_assets())
        self.assertFalse((self.site / "file.txt").exists())


class CacheValidationTests(unittest.TestCase):
    def test_compiler_signature_arguments_and_missing_dependencies_invalidate(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, compiled, output, deps = [root / name for name in ("source", "compiled", "output", "deps.json")]
            source.write_text("source")
            compiled.write_text("compiled")
            deps.write_text(json.dumps({"inputs": [str(source)]}))
            cache = BuildCache(root / "cache", {"compiler": "one"})
            cache.publish(compiled, output, deps, ["compile"],
                          inputs_before=snapshot_inputs([source]))
            self.assertTrue(cache.current(output, ["compile"], False))
            self.assertFalse(cache.current(output, ["compile", "--input", "changed=yes"], False))
            self.assertFalse(BuildCache(root / "cache", {"compiler": "two"}).current(output, ["compile"], False))
            source.unlink()
            self.assertFalse(cache.current(output, ["compile"], False))

    def test_invalid_dependencies_do_not_replace_previous_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            compiled, output, deps = [root / name for name in ("compiled", "output", "deps.json")]
            compiled.write_text("new")
            output.write_text("old")
            deps.write_text('{"inputs": []}')
            cache = BuildCache(root / "cache", {})
            with self.assertRaises(ValueError):
                cache.publish(compiled, output, deps, [], inputs_before={})
            self.assertEqual(output.read_text(), "old")

    def test_corrupt_record_is_a_cache_miss(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            cache = BuildCache(root / "cache", {})
            output = root / "page.html"
            output.write_text("old")
            cache.record_path(output).write_text("[]")
            self.assertFalse(cache.current(output, [], True))

    def test_metadata_rejects_invalid_types_and_dates(self):
        for data in (None, {}, {"schema": 1, "title": []}):
            with self.assertRaises(ValueError):
                validate_metadata(data)


if __name__ == "__main__":
    unittest.main()
