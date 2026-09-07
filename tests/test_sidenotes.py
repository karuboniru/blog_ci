import shutil
import subprocess
import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path

from build import strip_exported_endnotes


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = '''
#import "/tufted-lib/notes.typ": template-notes
#import "/tufted-lib/layout.typ": margin-note
#show: template-notes

Ordinary paragraph.

Before #footnote[Plain note.] after.

Before #footnote[
  Opening paragraph.

  - Bullet one.
    + Nested numbered item.
  - Bullet two.

  Closing paragraph.
] after.

Before #margin-note[
  - Manual bullet.
] after.

- List before #footnote[- List note.] list after.

#table(columns: 1, [Cell before #footnote[- Cell note.] cell after.])

#block(stroke: (left: 1pt))[
  Block before #footnote[- Block note.] block after.

  Another paragraph.
]
'''


class NoteStructure(HTMLParser):
    def __init__(self):
        super().__init__()
        self.stack = []
        self.notes = []
        self.note_lists = 0
        self.invalid_nesting = []
        self.broken_adjacency = []
        self.previous_start = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = attrs.get("class", "").split()
        if tag in {"div", "p", "ul", "ol", "table"}:
            if any(parent[0] in {"p", "span"} for parent in self.stack):
                self.invalid_nesting.append((tag, list(self.stack)))
        if "marginnote" in classes:
            self.notes.append(attrs)
            if "sidenote-footnote" in classes:
                reference_id = attrs.get("id", "").replace("fn-", "fnref-")
                if self.previous_start != ("a", reference_id):
                    self.broken_adjacency.append(attrs)
        if tag in {"ul", "ol"} and any("marginnote" in p[1] for p in self.stack):
            self.note_lists += 1
        self.previous_start = (tag, attrs.get("id"))
        if tag not in {"meta", "link", "br", "hr", "img", "input", "wbr"}:
            self.stack.append((tag, classes))

    def handle_endtag(self, tag):
        if self.stack and self.stack[-1][0] == tag:
            self.stack.pop()


@unittest.skipUnless(shutil.which("typst"), "Typst is required")
class SidenoteExportTests(unittest.TestCase):
    def test_block_notes_preserve_html_structure(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
            source = Path(temporary) / "notes.typ"
            output = source.with_suffix(".html")
            source.write_text(FIXTURE, encoding="utf-8")
            subprocess.run(
                [
                    "typst", "compile", "--root", str(ROOT), "--features", "html",
                    "--format", "html", str(source), str(output),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            html, _ = strip_exported_endnotes(output.read_text(encoding="utf-8"))

        parsed = NoteStructure()
        parsed.feed(html)
        self.assertEqual(parsed.invalid_nesting, [])
        self.assertEqual(parsed.broken_adjacency, [])
        self.assertEqual(len(parsed.notes), 6)
        self.assertEqual(parsed.note_lists, 6)
        self.assertIn("<p>Ordinary paragraph.</p>", html)
        self.assertIn("Closing paragraph.", html)
        self.assertIn("<p>Another paragraph.</p>", html)
        self.assertIn('class="sidenote-paragraph">Before', html)


if __name__ == "__main__":
    unittest.main()
