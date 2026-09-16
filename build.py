#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.10"
# ///

"""
Tufted Blog Template 构建脚本

这是一个跨平台的构建脚本，用于将 Typst (.typ) 文件编译为 HTML 和 PDF，
并复制静态资源到输出目录。

支持增量编译：只重新编译修改后的文件，加快构建速度。

用法:
    uv run build.py build       # 完整构建 (HTML + PDF + 资源)
    uv run build.py html        # 仅构建 HTML 文件
    uv run build.py pdf         # 仅构建 PDF 文件
    uv run build.py assets      # 仅复制静态资源
    uv run build.py clean       # 清理生成的文件
    uv run build.py preview     # 启动本地预览服务器（默认端口 8000）
    uv run build.py preview -p 3000  # 使用自定义端口
    uv run build.py --help      # 显示帮助信息

增量编译选项:
    --force, -f                 # 强制完整重建，忽略增量检查

预览服务器选项:
    --port, -p PORT             # 指定服务器端口号（默认: 8000）

也可以直接使用 Python 运行:
    python build.py build
    python build.py build --force
    python build.py preview -p 3000
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from typing import Literal

from build_cache import (BuildCache, DependenciesChanged, atomic_write, build_signature,
                         digest, read_json, snapshot_inputs, validate_metadata)

# ============================================================================
# 配置
# ============================================================================

CONTENT_DIR = Path("content")  # 源文件目录
SITE_DIR = Path("_site")  # 输出目录
ASSETS_DIR = Path("assets")  # 静态资源目录
BLOG_DERIVED_INDEXES = {
    Path("Blog/index.html"),
    Path("Tag/index.html"),
}


@dataclass
class BuildStats:
    """构建统计信息"""

    success: int = 0
    skipped: int = 0
    failed: int = 0

    def format_summary(self) -> str:
        """格式化统计摘要"""
        parts = []
        if self.success > 0:
            parts.append(f"编译: {self.success}")
        if self.skipped > 0:
            parts.append(f"跳过: {self.skipped}")
        if self.failed > 0:
            parts.append(f"失败: {self.failed}")
        return ", ".join(parts) if parts else "无文件需要处理"

    @property
    def has_failures(self) -> bool:
        """是否存在失败"""
        return self.failed > 0


@dataclass(frozen=True)
class GitLastModified:
    """A tracked file's most recent Git commit time and calendar date."""

    timestamp: int
    date: str


class HTMLStructureValidator(HTMLParser):
    """Validate generated documents without changing their serialized HTML."""

    def __init__(self):
        super().__init__()
        self.counts = {"html": 0, "head": 0, "body": 0}
        self.endnotes = False
        self.staging = False

    def handle_starttag(self, tag, attrs):
        if tag in self.counts:
            self.counts[tag] += 1
        attrs = dict(attrs)
        self.endnotes |= attrs.get("role") == "doc-endnotes"
        self.staging |= "data-tufted-head" in attrs


def validate_html(path: Path) -> None:
    parser = HTMLStructureValidator()
    parser.feed(path.read_text(encoding="utf-8"))
    parser.close()
    if any(count != 1 for count in parser.counts.values()) or parser.endnotes or parser.staging:
        raise ValueError(f"Invalid complete HTML document: {path}")


def get_typst_version() -> tuple[int, ...] | None:
    """
    获取当前 Typst CLI 的语义化版本号。

    返回:
        tuple[int, int, int] | None: 版本号，获取失败时返回 None
    """
    try:
        result = subprocess.run(
            ["typst", "--version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
    except (FileNotFoundError, OSError):
        return None

    if result.returncode != 0:
        return None

    match = re.search(r"typst (\d+)\.(\d+)\.(\d+)", result.stdout)
    if match is None:
        return None

    return tuple(int(component) for component in match.groups())




def cache_directory() -> Path:
    return SITE_DIR.parent / ".build-cache" / SITE_DIR.name


def page_path(source: Path) -> str:
    relative = source.relative_to(CONTENT_DIR)
    path = relative.parent if relative.name == "index.typ" else relative.with_suffix("")
    return "" if path == Path(".") else path.as_posix()


def html_sources() -> list[Path]:
    return [source for source in find_typ_files() if "pdf" not in source.stem.lower()]


def page_outputs() -> list[Path]:
    return [get_file_output_path(source, "html") for source in html_sources()]


def load_page_metadata(output: Path) -> dict:
    cache = BuildCache(cache_directory(), {})
    record = read_json(cache.record_path(output), {})
    return validate_metadata(record.get("metadata"))


def evaluate_page_metadata(source: Path) -> dict:
    result = subprocess.run(
        ["typst", "eval", "--root", ".", "--features", "html", "--target", "html",
         "--font-path", get_typst_font_path(), "--input", f"page-path={page_path(source)}",
         "--in", str(source), "query(<tufted-page>).map(it => it.value)"],
        capture_output=True, text=True, encoding="utf-8",
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    records = json.loads(result.stdout)
    if not isinstance(records, list) or len(records) != 1:
        raise ValueError(f"{source}: expected exactly one tufted-page metadata record")
    return validate_metadata(records[0])


def prune_outputs(kind: str, outputs: list[Path]) -> None:
    """Remove only outputs previously owned by this build stage."""
    manifest = cache_directory() / (kind + "-outputs.json")
    current = {path.relative_to(SITE_DIR).as_posix() for path in outputs}
    previous = read_json(manifest, None)
    if previous is None:
        # Adopt artifacts from builds made before output manifests existed.
        previous = [path.relative_to(SITE_DIR).as_posix()
                    for path in SITE_DIR.rglob("*." + kind)] if kind in {"html", "pdf"} else []
    for relative in set(previous) - current:
        path = SITE_DIR / relative
        if not path.resolve().is_relative_to(SITE_DIR.resolve()):
            raise ValueError(f"Output manifest escapes site directory: {relative}")
        path.unlink(missing_ok=True)
        BuildCache(cache_directory(), {}).record_path(path).unlink(missing_ok=True)
    atomic_write(manifest, json.dumps(sorted(current)))


def find_typ_files() -> list[Path]:
    """
    查找 content/ 目录下所有 .typ 文件，排除路径中包含以下划线开头的目录的文件。

    返回:
        list[Path]: .typ 文件路径列表
    """
    typ_files = []
    for typ_file in CONTENT_DIR.rglob("*.typ"):
        # 检查路径中是否有以下划线开头的目录
        parts = typ_file.relative_to(CONTENT_DIR).parts
        if not any(part.startswith("_") for part in parts):
            typ_files.append(typ_file)
    return sorted(typ_files)


def get_file_output_path(typ_file: Path, type: Literal["pdf", "html"]) -> Path:
    """
    获取 .typ 文件的输出路径。

    参数:
        typ_file: .typ 文件路径 (相对于 content/)

    返回:
        Path: 文件输出路径 (在 _site/ 目录下)
    """
    relative_path = typ_file.relative_to(CONTENT_DIR)
    return SITE_DIR / relative_path.with_suffix(f".{type}")


def get_typst_font_path() -> str:
    """Keep environment font paths when supplying the CLI font-path option."""
    paths = [str(ASSETS_DIR)]
    paths.extend(filter(None, os.environ.get("TYPST_FONT_PATHS", "").split(os.pathsep)))
    return os.pathsep.join(paths)


def run_typst_command(args: list[str]) -> bool:
    """
    运行 typst 命令。

    参数:
        args: typst 命令参数列表

    返回:
        bool: 命令是否成功执行
    """
    try:
        result = subprocess.run(["typst"] + args, capture_output=True, text=True, encoding="utf-8")
        if result.returncode != 0:
            print(f"  ❌ Typst 错误: {result.stderr.strip()}")
            return False
        if result.stderr.strip():
            print(result.stderr.strip())
        return True
    except FileNotFoundError:
        print("  ❌ 错误: 未找到 typst 命令。请确保已安装 Typst 并添加到 PATH 环境变量中。")
        print("  📝 安装说明: https://typst.app/open-source/#download")
        return False
    except Exception as e:
        print(f"  ❌ 执行 typst 命令时出错: {e}")
        return False


# ============================================================================
# 构建命令
# ============================================================================


def _compile_files(files: list[Path], force: bool, format: str) -> BuildStats:
    stats = BuildStats()
    version = get_typst_version()
    if version is None or version < (0, 15, 1):
        print("Typst 0.15.1+ is required for eval and JSON dependency output.")
        stats.failed = 1
        return stats
    cache = BuildCache(cache_directory(), build_signature(version, get_typst_font_path()))
    outputs = []
    for source in files:
        output = get_file_output_path(source, format)
        outputs.append(output)
        args = ["compile", "--root", ".", "--font-path", get_typst_font_path(),
                "--format", format]
        if format == "html":
            args += ["--features", "html", "--input", f"page-path={page_path(source)}"]
        args += [str(source), str(output)]
        if not force and cache.current(output, args, metadata=format == "html"):
            stats.skipped += 1
            continue
        try:
            with tempfile.TemporaryDirectory(dir=cache.directory) as temporary:
                temporary = Path(temporary)
                compiled = temporary / ("page." + format)
                deps = temporary / "dependencies.json"
                command = args[:-1] + [str(compiled), "--deps", str(deps), "--deps-format", "json"]
                known_inputs = cache.known_inputs(output, source)
                for attempt in range(3):
                    inputs_before = snapshot_inputs(known_inputs)
                    if not run_typst_command(command):
                        raise RuntimeError("Typst compilation failed")
                    metadata = None
                    if format == "html":
                        validate_html(compiled)
                        metadata = evaluate_page_metadata(source)
                    try:
                        cache.publish(compiled, output, deps, args, metadata,
                                      inputs_before=inputs_before)
                        break
                    except DependenciesChanged as error:
                        if attempt == 2:
                            raise
                        known_inputs = error.paths | {str(source.absolute())}
            stats.success += 1
        except (OSError, ValueError, RuntimeError) as error:
            print(f"Build failed for {source}: {error}")
            stats.failed += 1
    if not stats.has_failures:
        prune_outputs(format, outputs)
    return stats


def generate_blog_manifest() -> bool:
    """Generate the path-only manifest consumed by content/Blog/index.typ."""
    try:
        blog_dir = CONTENT_DIR / "Blog"
        blog_dir.mkdir(parents=True, exist_ok=True)
        post_files: list[Path] = []
        for typ_file in sorted(blog_dir.rglob("*.typ")):
            rel_path = typ_file.relative_to(blog_dir)
            if rel_path == Path("index.typ") or "pdf" in typ_file.stem.lower():
                continue
            if any(part.startswith("_") for part in rel_path.parts):
                continue
            post_files.append(typ_file)

        lines = [
            "// Generated by build.py. Only article paths belong here.",
            "#let post-sources = (",
        ]
        for typ_file in post_files:
            rel_path = typ_file.relative_to(blog_dir)
            if rel_path.name == "index.typ":
                page_path = rel_path.parent.as_posix() + "/"
            else:
                page_path = rel_path.with_suffix("").as_posix() + "/"
            lines.append("  (")
            lines.append(f"    source: {json.dumps(rel_path.as_posix(), ensure_ascii=False)},")
            lines.append(f"    path: {json.dumps(page_path, ensure_ascii=False)},")
            lines.append("  ),")
        lines.append(")")

        manifest_file = blog_dir / "_posts.typ"
        new_content = "\n".join(lines) + "\n"
        content_changed = (
            not manifest_file.exists()
            or manifest_file.read_text(encoding="utf-8") != new_content
        )
        if not content_changed:
            print(f"✅ 博客文章清单已是最新: {len(post_files)} 篇")
            return True

        atomic_write(manifest_file, new_content)
        print(f"✅ 博客文章清单生成完成: {len(post_files)} 篇")
        return True
    except Exception as e:
        print(f"❌ 生成博客文章清单失败: {e}")
        return False


def build_html(force: bool = False) -> bool:
    SITE_DIR.mkdir(parents=True, exist_ok=True)
    if not generate_blog_manifest():
        return False
    stats = _compile_files(html_sources(), force, "html")
    print(f"HTML: {stats.format_summary()}")
    return not stats.has_failures


def build_pdf(force: bool = False) -> bool:
    SITE_DIR.mkdir(parents=True, exist_ok=True)
    stats = _compile_files(
        [source for source in find_typ_files() if "pdf" in source.stem.lower()],
        force, "pdf",
    )
    print(f"PDF: {stats.format_summary()}")
    return not stats.has_failures


def copy_asset_files(files: list[tuple[Path, Path]], kind: str, force: bool = False) -> bool:
    try:
        for source, output in files:
            if force or not output.exists() or digest(source) != digest(output):
                atomic_write(output, source.read_bytes())
        prune_outputs(kind, [output for _, output in files])
        return True
    except (OSError, ValueError) as error:
        print(f"Asset copy failed: {error}")
        return False


def copy_assets() -> bool:
    files = [(source, SITE_DIR / "assets" / source.relative_to(ASSETS_DIR))
             for source in sorted(ASSETS_DIR.rglob("*")) if source.is_file()]
    return copy_asset_files(files, "assets")


def copy_content_assets(force: bool = False) -> bool:
    files = [(source, SITE_DIR / source.relative_to(CONTENT_DIR))
             for source in sorted(CONTENT_DIR.rglob("*"))
             if source.is_file() and source.suffix != ".typ"
             and not any(part.startswith("_") for part in source.relative_to(CONTENT_DIR).parts)]
    return copy_asset_files(files, "content-assets", force)


def clean() -> bool:
    """
    清理生成的文件。
    """
    print("正在清理生成的文件...")

    if not SITE_DIR.exists():
        print(f"  输出目录 {SITE_DIR} 不存在，无需清理。")
        return True

    try:
        # 删除 _site 目录下的所有内容
        for item in SITE_DIR.iterdir():
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()

        print(f"  ✅ 已清理 {SITE_DIR}/ 目录。")
        return True
    except Exception as e:
        print(f"  ❌ 清理失败: {e}")
        return False


def preview(port: int = 8000, open_browser_flag: bool = True) -> bool:
    """
    启动本地预览服务器。

    首先尝试使用 uvx livereload（支持实时刷新），
    如果失败则回退到 Python 内置的 http.server。

    参数:
        port: 服务器端口号，默认为 8000
        open_browser_flag: 是否自动打开浏览器，默认为 True
    """
    import webbrowser

    if not SITE_DIR.exists():
        print(f"  ⚠ 输出目录 {SITE_DIR} 不存在，请先运行 build 命令。")
        return False

    print("正在启动本地预览服务器（按 Ctrl+C 停止）...")
    print()

    if open_browser_flag:

        def open_browser():
            time.sleep(1.5)  # 等待服务器启动
            url = f"http://localhost:{port}"
            print(f"  🚀 正在打开浏览器: {url}")
            webbrowser.open(url)

        # 在后台线程中打开浏览器
        threading.Thread(target=open_browser, daemon=True).start()

    # 首先尝试 uvx livereload
    try:
        result = subprocess.run(
            ["uvx", "livereload", str(SITE_DIR), "-p", str(port)],
            check=False,
        )
        return result.returncode == 0
    except FileNotFoundError:
        print("  未找到 uv，尝试 Python http.server...")
    except KeyboardInterrupt:
        print("\n服务器已停止。")
        return True

    # 回退到 Python http.server
    try:
        print("使用 Python 内置 http.server...")
        result = subprocess.run(
            [sys.executable, "-m", "http.server", str(port), "--directory", str(SITE_DIR)],
            check=False,
        )
        return result.returncode == 0
    except KeyboardInterrupt:
        print("\n服务器已停止。")
        return True
    except Exception as e:
        print(f"  ❌ 启动服务器失败: {e}")
        return False


def get_site_url() -> str | None:
    return load_page_metadata(SITE_DIR / "index.html")["link"].rstrip("/") or None


def get_feed_dirs() -> set[str]:
    return {directory.strip("/") or "/" for directory in
            load_page_metadata(SITE_DIR / "index.html")["feed-dirs"]}


def extract_post_metadata(index_html: Path) -> tuple[str, str, str, datetime | None]:
    """Read evaluated page metadata; retain the legacy path-date fallback."""
    metadata = load_page_metadata(index_html)
    date = metadata["date"]
    if not date:
        match = re.search(r"(\d{4}-\d{2}-\d{2})", index_html.parent.name)
        date = match.group(1) if match else ""
    published = datetime.fromisoformat(date.split("T")[0]).replace(tzinfo=timezone.utc) if date else None
    return metadata["title"].strip(), metadata["description"].strip(), metadata["link"], published


def collect_posts(dirs: set[str]) -> list[dict]:
    """Collect current index pages once, even when feed directories overlap."""
    roots = [SITE_DIR if directory in ("", "/") else SITE_DIR / directory for directory in dirs]
    posts = []
    for output in page_outputs():
        if output.name != "index.html" or not any(output.is_relative_to(root) for root in roots):
            continue
        title, description, link, date = extract_post_metadata(output)
        if date is not None:
            posts.append(dict(title=title, description=description, link=link, date=date,
                              dir=output.relative_to(SITE_DIR).parts[0]))
    return posts


def build_rss_xml(posts: list[dict], config: dict) -> str:
    """
    构建符合 RSS 2.0 规范的 XML 内容字符串。

    功能:
        使用 Python 标准库 xml.etree.ElementTree 根据文章数据和站点配置生成完整的 RSS Feed XML。
        支持条件输出 description 标签（仅在有描述时输出）。

    参数:
        posts (list[dict]): 文章数据列表，每个字典应包含:
            - title: 标题
            - description: 描述（可选）
            - link: 文章链接
            - date: datetime 对象
            - dir: 分类名称 (即路径名)
        config (dict): 站点配置字典，应包含:
            - site_url: 站点根 URL
            - site_title: 站点标题
            - site_description: 站点描述
            - lang: 语言代码（如 "zh", "en"）

    返回:
        str: 完整的 RSS 2.0 XML 字符串，包含 XML 声明和所有必要的命名空间。
    """
    import xml.etree.ElementTree as ET
    from email.utils import format_datetime

    # 注册 atom 命名空间前缀
    ATOM_NS = "http://www.w3.org/2005/Atom"
    ET.register_namespace("atom", ATOM_NS)

    # 创建 RSS 根元素（命名空间声明由 register_namespace 自动处理）
    rss = ET.Element("rss", version="2.0")

    # Channel 元数据
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = config["site_title"]
    ET.SubElement(channel, "link").text = config["site_url"]
    ET.SubElement(channel, "description").text = config["site_description"]
    ET.SubElement(channel, "language").text = config["lang"]
    ET.SubElement(channel, "lastBuildDate").text = format_datetime(datetime.now(timezone.utc))

    # 添加 atom:link 自链接
    atom_link = ET.SubElement(channel, f"{{{ATOM_NS}}}link")
    atom_link.set("href", f"{config['site_url']}/feed.xml")
    atom_link.set("rel", "self")
    atom_link.set("type", "application/rss+xml")

    # 添加文章条目
    for post in posts:
        item = ET.SubElement(channel, "item")

        ET.SubElement(item, "title").text = post["title"]
        ET.SubElement(item, "link").text = post["link"]
        ET.SubElement(item, "guid", isPermaLink="true").text = post["link"]
        ET.SubElement(item, "pubDate").text = format_datetime(post["date"])
        ET.SubElement(item, "category").text = post["dir"]

        # 仅在有描述时添加
        if des := post["description"]:
            ET.SubElement(item, "description").text = des

    # 生成 XML 字符串
    ET.indent(rss, space="  ")
    xml_str = ET.tostring(rss, encoding="unicode", xml_declaration=False)

    return f'<?xml version="1.0" encoding="UTF-8"?>\n{xml_str}'


def generate_rss(site_url: str) -> bool:
    """Generate RSS from the current source inventory and evaluated metadata."""
    rss_file = SITE_DIR / "feed.xml"
    dirs = get_feed_dirs()
    posts = collect_posts(dirs)
    if not dirs or not posts:
        rss_file.unlink(missing_ok=True)
        return True
    posts.sort(key=lambda post: post["date"], reverse=True)
    metadata = load_page_metadata(SITE_DIR / "index.html")
    config = dict(site_url=site_url, site_title=metadata["title"].strip(),
                  site_description=metadata["description"].strip(), lang=metadata["lang"])
    atomic_write(rss_file, build_rss_xml(posts, config))
    print(f"RSS: {len(posts)} articles")
    return True


def get_git_last_modified(path: Path) -> GitLastModified:
    """Return the latest commit time for one tracked file, following renames."""
    result = subprocess.run(
        [
            "git",
            "log",
            "-1",
            "--follow",
            "--format=%ct%x00%cs",
            "--",
            path.as_posix(),
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or f"git log exited with {result.returncode}"
        raise RuntimeError(f"无法读取 {path} 的 Git 历史: {detail}")

    output = result.stdout.strip()
    if not output:
        raise RuntimeError(f"Git 历史中没有源文件: {path}")

    try:
        timestamp_text, commit_date = output.split("\x00", maxsplit=1)
        return GitLastModified(timestamp=int(timestamp_text), date=commit_date)
    except (TypeError, ValueError) as e:
        raise RuntimeError(f"无法解析 {path} 的 Git 修改时间: {output!r}") from e


def find_blog_post_sources() -> list[Path]:
    """Return actual blog post sources, excluding the index and helper files."""
    blog_dir = CONTENT_DIR / "Blog"
    if not blog_dir.exists():
        return []

    post_sources = []
    for typ_file in sorted(blog_dir.rglob("*.typ")):
        rel_path = typ_file.relative_to(blog_dir)
        if rel_path == Path("index.typ") or "pdf" in typ_file.stem.lower():
            continue
        if any(part.startswith("_") for part in rel_path.parts):
            continue
        post_sources.append(typ_file)
    return post_sources


def find_latest_blog_post_source() -> tuple[Path, datetime]:
    """Find the latest blog post using the same published date as the archive."""
    dated_posts: list[tuple[datetime, Path]] = []
    for source_path in find_blog_post_sources():
        html_path = SITE_DIR / source_path.relative_to(CONTENT_DIR).with_suffix(".html")
        if not html_path.exists():
            raise RuntimeError(f"博客文章缺少已生成的 HTML: {html_path}")
        _, _, _, published_at = extract_post_metadata(html_path)
        if published_at is not None:
            dated_posts.append((published_at, source_path))

    if not dated_posts:
        raise RuntimeError("Blog/index.html 没有带发布日期的博客文章")

    published_at, source_path = max(dated_posts, key=lambda item: item[0])
    return source_path, published_at


def get_sitemap_lastmod(
    html_path: Path,
    git_dates: dict[Path, GitLastModified],
) -> tuple[str, Path]:
    """Resolve an HTML page's sitemap date from its source file's Git history."""
    rel_path = html_path.relative_to(SITE_DIR)

    def cached_git_date(source_path: Path) -> GitLastModified:
        if source_path not in git_dates:
            git_dates[source_path] = get_git_last_modified(source_path)
        return git_dates[source_path]

    if rel_path in BLOG_DERIVED_INDEXES:
        latest_source, _ = find_latest_blog_post_source()
        return cached_git_date(latest_source).date, latest_source

    source_path = CONTENT_DIR / rel_path.with_suffix(".typ")
    return cached_git_date(source_path).date, source_path


def generate_sitemap(site_url: str) -> bool:
    """
    使用 Python 标准库 xml.etree.ElementTree 生成 sitemap.xml。
    """
    import xml.etree.ElementTree as ET

    sitemap_path = SITE_DIR / "sitemap.xml"
    sitemap_ns = "http://www.sitemaps.org/schemas/sitemap/0.9"

    # 注册默认命名空间
    ET.register_namespace("", sitemap_ns)

    # 创建根元素
    urlset = ET.Element("urlset", xmlns=sitemap_ns)

    shallow_result = subprocess.run(
        ["git", "rev-parse", "--is-shallow-repository"],
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if shallow_result.returncode != 0:
        print("❌ Sitemap 构建失败: 当前目录不是可读取历史的 Git 仓库")
        return False
    if shallow_result.stdout.strip() == "true":
        print("❌ Sitemap 构建失败: Git 仓库是浅克隆，请先运行 git fetch --unshallow")
        return False

    print("ℹ️ Sitemap lastmod 使用对应 .typ 文件的 Git 最后提交日期")
    git_dates: dict[Path, GitLastModified] = {}
    derived_index_dates: dict[Path, tuple[str, Path]] = {}

    try:
        # 遍历 _site 目录
        for file_path in page_outputs():
            rel_path = file_path.relative_to(SITE_DIR).as_posix()

            # 确定 URL 路径
            if rel_path == "index.html":
                url_path = ""
            elif rel_path.endswith("/index.html"):
                url_path = rel_path.removesuffix("index.html")
            elif rel_path.endswith(".html"):
                url_path = rel_path.removesuffix(".html") + "/"
            else:
                url_path = rel_path

            full_url = f"{site_url}/{url_path}"

            # 从对应 Typst 源文件的 Git 历史获取最后修改日期。
            lastmod, source_path = get_sitemap_lastmod(file_path, git_dates)
            rel_page = Path(rel_path)
            if rel_page in BLOG_DERIVED_INDEXES:
                derived_index_dates[rel_page] = (lastmod, source_path)

            # 创建 url 元素
            url_elem = ET.SubElement(urlset, "url")
            ET.SubElement(url_elem, "loc").text = full_url
            ET.SubElement(url_elem, "lastmod").text = lastmod
    except RuntimeError as e:
        print(f"❌ Sitemap 构建失败: {e}")
        return False

    for rel_path in sorted(derived_index_dates):
        lastmod, source_path = derived_index_dates[rel_path]
        print(
            f"ℹ️ {rel_path.as_posix()} lastmod: "
            f"{lastmod}（按发布日期选择最新文章 "
            f"{source_path.as_posix()}）"
        )

    # 生成 XML 字符串
    ET.indent(urlset, space="  ")
    xml_str = ET.tostring(urlset, encoding="unicode", xml_declaration=False)
    sitemap_content = f'<?xml version="1.0" encoding="UTF-8"?>\n{xml_str}'

    try:
        atomic_write(sitemap_path, sitemap_content)
        print(f"✅ Sitemap 构建完成: 包含 {len(urlset)} 个页面")
        return True
    except Exception as e:
        print(f"❌ Sitemap 构建失败: {e}")
        return False


def generate_robots_txt(site_url: str) -> bool:
    """
    Generate robots.txt pointing to the sitemap.
    """
    robots_content = f"""User-agent: *
Allow: /

Sitemap: {site_url}/sitemap.xml
"""

    try:
        atomic_write(SITE_DIR / "robots.txt", robots_content)
        return True
    except Exception as e:
        print(f"❌ 生成 robots.txt 失败: {e}")
        return False


def generate_cloudflare_redirects() -> bool:
    """Generate year-scoped redirects for legacy blog URLs."""
    blog_dir = CONTENT_DIR / "Blog"
    redirects_file = SITE_DIR / "_redirects"

    try:
        years = sorted(
            path.name
            for path in blog_dir.iterdir()
            if path.is_dir()
            and re.fullmatch(r"\d{4}", path.name)
            and any(path.rglob("index.typ"))
        )
        rules = [
            f"/{year}/:month/:day/:slug/ /Blog/{year}/:slug/ 301"
            for year in years
        ]
        atomic_write(redirects_file, "\n".join(rules) + "\n")
        print(f"✅ Cloudflare Redirects 生成完成: {len(rules)} 条")
        return True
    except Exception as e:
        print(f"❌ 生成 Cloudflare Redirects 失败: {e}")
        return False


def build(force: bool = False) -> bool:
    """
    完整构建：HTML + PDF + 资源。

    参数:
        force: 是否强制重建所有文件
    """
    print("-" * 60)
    if force:
        print("🛠️ 开始完整构建...")
    else:
        print("🚀 开始增量构建...")
    print("-" * 60)

    # 确保输出目录存在
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    results = []

    print()
    results.append(build_html(force))
    results.append(build_pdf(force))
    if not all(results):
        return False
    print()

    results.append(copy_assets())
    results.append(copy_content_assets(force))
    results.append(generate_cloudflare_redirects())

    try:
        if site_url := get_site_url():
            results.append(generate_sitemap(site_url))
            results.append(generate_robots_txt(site_url))
            results.append(generate_rss(site_url))
        else:
            for name in ("sitemap.xml", "robots.txt", "feed.xml"):
                (SITE_DIR / name).unlink(missing_ok=True)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"Metadata generation failed: {error}")
        return False

    print("-" * 60)
    if all(results):
        print("✅ 所有构建任务完成！")
        print(f"  📂 输出目录: {SITE_DIR.absolute()}")
    else:
        print("⚠ 构建完成，但有部分任务失败。")
    print("-" * 60)

    return all(results)


# ============================================================================
# 命令行接口
# ============================================================================


def create_parser() -> argparse.ArgumentParser:
    """
    创建命令行参数解析器。
    """
    parser = argparse.ArgumentParser(
        prog="build.py",
        description="Tufted Blog Template 构建脚本 - 将 content 中的 Typst 文件编译为 HTML 和 PDF",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
构建脚本默认只重新编译修改过的文件，可使用 -f/--force 选项强制完整重建：
    uv run build.py build --force
    或 python build.py build -f

使用 preview 命令启动本地预览服务器：
    uv run build.py preview
    或 python build.py preview -p 3000  # 使用自定义端口

更多信息请参阅 README.md
""",
    )

    subparsers = parser.add_subparsers(dest="command", title="可用命令", metavar="<command>")

    build_parser = subparsers.add_parser("build", help="完整构建 (HTML + PDF + 资源)")
    build_parser.add_argument("-f", "--force", action="store_true", help="强制完整重建")

    html_parser = subparsers.add_parser("html", help="仅构建 HTML 文件")
    html_parser.add_argument("-f", "--force", action="store_true", help="强制完整重建")

    pdf_parser = subparsers.add_parser("pdf", help="仅构建 PDF 文件")
    pdf_parser.add_argument("-f", "--force", action="store_true", help="强制完整重建")

    subparsers.add_parser("assets", help="仅复制静态资源")
    subparsers.add_parser("clean", help="清理生成的文件")

    preview_parser = subparsers.add_parser("preview", help="启动本地预览服务器")
    preview_parser.add_argument(
        "-p", "--port", type=int, default=8000, help="服务器端口号（默认: 8000）"
    )
    preview_parser.add_argument(
        "--no-open", action="store_false", dest="open_browser", help="不自动打开浏览器"
    )
    preview_parser.set_defaults(open_browser=True)

    return parser


if __name__ == "__main__":
    parser = create_parser()
    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        sys.exit(0)

    # 确保在项目根目录运行
    script_dir = Path(__file__).parent.absolute()
    os.chdir(script_dir)

    # 获取 force 参数
    force = getattr(args, "force", False)

    # 使用 match-case 执行对应的命令
    match args.command:
        case "build":
            success = build(force)
        case "html":
            success = build_html(force)
        case "pdf":
            success = build_pdf(force)
        case "assets":
            success = copy_assets()
        case "clean":
            success = clean()
        case "preview":
            success = preview(getattr(args, "port", 8000), getattr(args, "open_browser", True))
        case _:
            print(f"❌ 未知命令: {args.command}")
            success = False

    sys.exit(0 if success else 1)
