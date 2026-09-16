"""Compare site artifacts across a build migration (python tests/compare_builds.py OLD NEW)."""

import argparse
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path


class Document(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.head, self.body = [], []
        self.events = self.head
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        if tag == "body":
            self.events = self.body
        self.events.append(("start", tag, tuple(sorted(attrs))))

    def handle_endtag(self, tag):
        self.events.append(("end", tag))

    def handle_data(self, data):
        self.events.append(("text", data))

    def handle_comment(self, data):
        self.events.append(("comment", data))

    def normalized_body(self):
        links = {dict(event[2]).get("href") for event in self.body if event[0] == "start"}
        result = []
        for event in self.body:
            if event[:2] == ("start", "sup"):
                attrs = dict(event[2])
                identifier = attrs.get("id", "")
                # The old exporter's removed endnotes left unused backlink targets.
                if (attrs.get("class") == "footnote-ref" and re.fullmatch(r"loc-\d+", identifier)
                        and "#" + identifier not in links):
                    del attrs["id"]
                    event = ("start", "sup", tuple(sorted(attrs.items())))
            result.append(event)
        return result

    def resources(self):
        return [event for event in self.head if event[0] == "start"
                and event[1] in {"script", "link"}]


def compare_pdf(before, after):
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        rendered = []
        for name, path in (("old", before), ("new", after)):
            subprocess.run(["pdftoppm", "-r", "96", "-png", str(path), str(root / name)],
                           check=True, capture_output=True)
            rendered.append([page.read_bytes() for page in sorted(root.glob(name + "-*.png"))])
        assert rendered[0] == rendered[1], f"PDF pixels differ: {before}"
        texts = [subprocess.check_output(["pdftotext", str(path), "-"]) for path in (before, after)]
        assert texts[0] == texts[1], f"PDF text differs: {before}"


def compare(before, after):
    inventories = [{path.relative_to(root) for path in root.rglob("*") if path.is_file()}
                   for root in (before, after)]
    assert inventories[0] == inventories[1], f"Inventory differs: {inventories[0] ^ inventories[1]}"
    html_count = 0
    for relative in sorted(inventories[0]):
        old, new = before / relative, after / relative
        if relative.suffix == ".html":
            a, b = Document(old.read_text()), Document(new.read_text())
            assert a.normalized_body() == b.normalized_body(), f"Body differs: {relative}"
            assert Counter(a.head) == Counter(b.head), f"Head content differs: {relative}"
            assert a.resources() == b.resources(), f"Resource order differs: {relative}"
            html_count += 1
        elif relative == Path("feed.xml"):
            trees = [ET.parse(path) for path in (old, new)]
            for tree in trees:
                tree.find("channel/lastBuildDate").text = "BUILD_TIME"
            assert ET.tostring(trees[0].getroot()) == ET.tostring(trees[1].getroot()), "RSS differs"
        elif relative.suffix == ".pdf":
            compare_pdf(old, new)
        else:
            assert old.read_bytes() == new.read_bytes(), f"Artifact differs: {relative}"
    print(f"Equivalent: {html_count} HTML pages, PDF pixels/text, RSS, and remaining artifacts")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    args = parser.parse_args()
    compare(args.before, args.after)
