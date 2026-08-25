import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch

import build


class SitemapLastmodTests(unittest.TestCase):
    def test_get_git_last_modified_parses_timestamp_and_date(self):
        completed = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="1756081817\x002025-08-25\n", stderr=""
        )

        with patch.object(build.subprocess, "run", return_value=completed):
            modified = build.get_git_last_modified(Path("content/page.typ"))

        self.assertEqual(modified, build.GitLastModified(1756081817, "2025-08-25"))

    def test_blog_index_uses_git_date_of_latest_published_article(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            content_dir = root / "content"
            site_dir = root / "_site"
            old_post = content_dir / "Blog/2024/old/index.typ"
            new_post = content_dir / "Blog/2025/new/index.typ"
            old_post_html = site_dir / "Blog/2024/old/index.html"
            new_post_html = site_dir / "Blog/2025/new/index.html"
            blog_index = content_dir / "Blog/index.typ"
            ignored_helper = content_dir / "Blog/_posts.typ"
            for path in (old_post, new_post, blog_index, ignored_helper):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()
            old_post_html.parent.mkdir(parents=True, exist_ok=True)
            old_post_html.write_text(
                '<meta name="date" content="2024-01-02">', encoding="utf-8"
            )
            new_post_html.parent.mkdir(parents=True, exist_ok=True)
            new_post_html.write_text(
                '<meta name="date" content="2025-03-04">', encoding="utf-8"
            )

            dates = {
                # Commit order deliberately disagrees with publication order.
                old_post: build.GitLastModified(200, "2025-05-06"),
                new_post: build.GitLastModified(100, "2025-03-05"),
            }

            with (
                patch.object(build, "CONTENT_DIR", content_dir),
                patch.object(build, "SITE_DIR", site_dir),
                patch.object(build, "get_git_last_modified", side_effect=dates.__getitem__),
            ):
                lastmod, source = build.get_sitemap_lastmod(
                    site_dir / "Blog/index.html", {}
                )

        self.assertEqual(lastmod, "2025-03-05")
        self.assertEqual(source, new_post)

    def test_generate_sitemap_uses_source_commit_dates(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            content_dir = root / "content"
            site_dir = root / "_site"
            home_html = site_dir / "index.html"
            blog_html = site_dir / "Blog/index.html"
            post_source = content_dir / "Blog/2025/post/index.typ"
            for path in (home_html, blog_html, post_source):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()

            git_check = subprocess.CompletedProcess(
                args=[], returncode=0, stdout="false\n", stderr=""
            )

            def sitemap_date(html_path, _git_dates):
                if html_path == blog_html:
                    return "2025-06-07", post_source
                return "2024-02-03", content_dir / "index.typ"

            with (
                patch.object(build, "CONTENT_DIR", content_dir),
                patch.object(build, "SITE_DIR", site_dir),
                patch.object(build.subprocess, "run", return_value=git_check),
                patch.object(build, "get_sitemap_lastmod", side_effect=sitemap_date),
            ):
                self.assertTrue(build.generate_sitemap("https://example.com"))

            root_element = ET.parse(site_dir / "sitemap.xml").getroot()
            namespace = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}
            entries = {
                entry.findtext("s:loc", namespaces=namespace): entry.findtext(
                    "s:lastmod", namespaces=namespace
                )
                for entry in root_element.findall("s:url", namespace)
            }

        self.assertEqual(
            entries,
            {
                "https://example.com/": "2024-02-03",
                "https://example.com/Blog/": "2025-06-07",
            },
        )


if __name__ == "__main__":
    unittest.main()
