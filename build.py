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
from dataclasses import dataclass
from datetime import datetime, timezone
from html import escape as escape_html
from html.parser import HTMLParser
from pathlib import Path
from typing import Literal

# ============================================================================
# 配置
# ============================================================================

CONTENT_DIR = Path("content")  # 源文件目录
SITE_DIR = Path("_site")  # 输出目录
ASSETS_DIR = Path("assets")  # 静态资源目录
CONFIG_FILE = Path("config.typ")  # 全局配置文件
MATHML_MIN_TYPST_VERSION = (0, 15, 0)


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


class HTMLMetadataParser(HTMLParser):
    """
    从 HTML 文件中提取元数据的解析器。

    解析以下元数据：
    - lang: 从 <html lang="..."> 属性获取
    - title: 从 <title> 标签获取
    - author: 从 <meta name="authors" content="..."> 获取
    - description: 从 <meta name="description" content="..."> 获取
    - link: 从 <link rel="canonical" href="..."> 获取
    - date: 从 <meta name="date" content="..."> 获取
    """

    def __init__(self):
        super().__init__()
        self.metadata = {"title": ""}
        self._in_title = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]):
        attrs_dict = {k: v for k, v in attrs if v}

        match tag:
            case "html":
                self.metadata["lang"] = attrs_dict.get("lang", "")
            case "title":
                self._in_title = True
            case "meta":
                name = attrs_dict.get("name", "")
                if name in {"author", "authors"}:
                    self.metadata["author"] = attrs_dict.get("content", "")
                elif name in {"description", "date"}:
                    self.metadata[name] = attrs_dict.get("content", "")
            case "link":
                if attrs_dict.get("rel") == "canonical":
                    self.metadata["link"] = attrs_dict.get("href", "")

    def handle_endtag(self, tag: str):
        if tag == "title":
            self._in_title = False

    def handle_data(self, data: str):
        if self._in_title:
            self.metadata["title"] += data


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


def warn_if_typst_version_is_outdated() -> None:
    """
    对低于 MathML 支持基线的 Typst 版本输出提示。
    """
    version = get_typst_version()
    if version is None or version >= MATHML_MIN_TYPST_VERSION:
        return

    current = ".".join(str(component) for component in version)
    required = ".".join(str(component) for component in MATHML_MIN_TYPST_VERSION)
    print(
        f"  ⚠️ 检测到 Typst {current}。HTML 导出的原生 MathML 公式支持需要 Typst {required}+，建议升级 Typst 版本。"
    )


# ============================================================================
# 增量编译辅助函数
# ============================================================================


def get_file_mtime(path: Path) -> float:
    """
    获取文件的修改时间戳。

    参数:
        path: 文件路径

    返回:
        float: 修改时间戳，文件不存在返回 0
    """
    try:
        return path.stat().st_mtime
    except (OSError, FileNotFoundError):
        return 0.0


def find_typ_dependencies(typ_file: Path) -> set[Path]:
    """
    解析 .typ 文件中的依赖（通过 #import 和 #include 导入的文件）。

    只追踪显式 import/include 的 .typ 文件。页面也可能作为模块被导入，
    例如博客目录会动态读取各文章导出的 post 元数据。

    参数:
        typ_file: .typ 文件路径

    返回:
        set[Path]: 依赖的 .typ 文件路径集合
    """
    dependencies: set[Path] = set()

    try:
        content = typ_file.read_text(encoding="utf-8")
    except Exception:
        return dependencies

    # 获取文件所在目录，用于解析相对路径
    base_dir = typ_file.parent

    patterns = [
        r'#import\s+"([^"]+)"',
        r"#import\s+'([^']+)'",
        r'#include\s+"([^"]+)"',
        r"#include\s+'([^']+)'",
    ]

    for pattern in patterns:
        for match in re.finditer(pattern, content):
            dep_path_str = match.group(1)

            # 跳过包导入（如 @preview/xxx）
            if dep_path_str.startswith("@"):
                continue

            # 解析相对路径
            if dep_path_str.startswith("/"):
                # 相对于项目根目录的路径
                dep_path = Path(dep_path_str.lstrip("/"))
            else:
                # 相对于当前文件的路径
                dep_path = base_dir / dep_path_str

            # 规范化路径，只追踪 .typ 文件
            try:
                dep_path = dep_path.resolve()
                if dep_path.exists() and dep_path.suffix == ".typ":
                    dependencies.add(dep_path)
            except Exception:
                pass

    return dependencies


def get_all_dependencies(typ_file: Path, visited: set[Path] | None = None) -> set[Path]:
    """
    递归获取 .typ 文件的所有依赖（包括传递依赖）。

    参数:
        typ_file: .typ 文件路径
        visited: 已访问的文件集合（用于避免循环依赖）

    返回:
        set[Path]: 所有依赖文件路径集合
    """
    if visited is None:
        visited = set()

    # 避免循环依赖
    abs_path = typ_file.resolve()
    if abs_path in visited:
        return set()
    visited.add(abs_path)

    all_deps: set[Path] = set()
    direct_deps = find_typ_dependencies(typ_file)

    for dep in direct_deps:
        all_deps.add(dep)
        # 只对 .typ 文件递归查找依赖
        if dep.suffix == ".typ":
            all_deps.update(get_all_dependencies(dep, visited))

    return all_deps


def needs_rebuild(source: Path, target: Path, extra_deps: list[Path] | None = None) -> bool:
    """
    判断是否需要重新构建。

    当以下任一条件满足时需要重建：
    1. 目标文件不存在
    2. 源文件比目标文件新
    3. 任何额外依赖文件比目标文件新
    4. 源文件的任何导入依赖比目标文件新
    5. 源文件同目录下的任何非 .typ 文件比目标文件新（如 .md, .bib, 图片等）

    参数:
        source: 源文件路径
        target: 目标文件路径
        extra_deps: 额外的依赖文件列表（如 config.typ）

    返回:
        bool: 是否需要重新构建
    """
    # 目标不存在，需要构建
    if not target.exists():
        return True

    target_mtime = get_file_mtime(target)

    # 源文件更新了
    if get_file_mtime(source) > target_mtime:
        return True

    # 检查额外依赖
    if extra_deps:
        for dep in extra_deps:
            if dep.exists() and get_file_mtime(dep) > target_mtime:
                return True

    # 检查源文件的导入依赖
    for dep in get_all_dependencies(source):
        if get_file_mtime(dep) > target_mtime:
            return True

    # 检查源文件同目录下的非 .typ 资源文件（如 .md, .bib, 图片等）
    # 只检查同一目录，不递归子目录，避免过度重编译
    source_dir = source.parent
    for item in source_dir.iterdir():
        if item.is_file() and item.suffix != ".typ":
            if get_file_mtime(item) > target_mtime:
                return True

    return False


def find_common_dependencies() -> list[Path]:
    """
    查找所有文件的公共依赖（如 config.typ）。

    返回:
        list[Path]: 公共依赖文件路径列表
    """
    common_deps = []

    # config.typ 是全局配置，修改后所有页面都需要重建
    if CONFIG_FILE.exists():
        common_deps.append(CONFIG_FILE)

    # 可以在这里添加其他公共依赖
    # 例如：查找 content/_* 目录下的模板文件
    if CONTENT_DIR.exists():
        for item in CONTENT_DIR.iterdir():
            if item.is_dir() and item.name.startswith("_"):
                for typ_file in item.rglob("*.typ"):
                    common_deps.append(typ_file)

    return common_deps


# ============================================================================
# 辅助函数
# ============================================================================


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
    return typ_files


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


def _compile_files(
    files: list[Path],
    force: bool,
    common_deps: list[Path],
    get_output_path_func,
    build_args_func,
    postprocess_func=None,
) -> BuildStats:
    """
    通用文件编译函数，减少重复代码。

    参数:
        files: 要编译的文件列表
        force: 是否强制重建
        common_deps: 公共依赖列表
        get_output_path_func: 获取输出路径的函数
        build_args_func: 构建编译参数的函数
        postprocess_func: 可选的编译后处理函数

    返回:
        BuildStats: 构建统计信息
    """
    stats = BuildStats()

    for typ_file in files:
        output_path = get_output_path_func(typ_file)

        # 增量编译检查
        if not force and not needs_rebuild(typ_file, output_path, common_deps):
            stats.skipped += 1
            continue

        output_path.parent.mkdir(parents=True, exist_ok=True)

        # 构建编译参数
        args = build_args_func(typ_file, output_path)

        if run_typst_command(args):
            if postprocess_func is None or postprocess_func(typ_file, output_path):
                stats.success += 1
            else:
                print(f"  ❌ {typ_file} 后处理失败")
                stats.failed += 1
        else:
            print(f"  ❌ {typ_file} 编译失败")
            stats.failed += 1

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
        source_changed = manifest_file.exists() and any(
            get_file_mtime(path) > get_file_mtime(manifest_file) for path in post_files
        )
        if not content_changed and not source_changed:
            print(f"✅ 博客文章清单已是最新: {len(post_files)} 篇")
            return True

        manifest_file.write_text(new_content, encoding="utf-8")
        print(f"✅ 博客文章清单生成完成: {len(post_files)} 篇")
        return True
    except Exception as e:
        print(f"❌ 生成博客文章清单失败: {e}")
        return False


HEAD_STAGING_RE = re.compile(
    r'<template\s+data-tufted-head(?:="")?>(.*?)</template>',
    re.DOTALL,
)
FINALIZED_HEAD_MARKER = '<meta property="og:title"'


class ExportedEndnotesLocator(HTMLParser):
    """Locate Typst's automatically appended HTML endnotes in the source text."""

    def __init__(self, html_text: str):
        super().__init__(convert_charrefs=False)
        self.html_text = html_text
        self.ranges: list[tuple[int, int]] = []
        self._line_starts = [0]
        self._line_starts.extend(
            match.end() for match in re.finditer(r"\n", html_text)
        )
        self._section_depth = 0
        self._range_start: int | None = None

    def _absolute_position(self) -> int:
        line, column = self.getpos()
        return self._line_starts[line - 1] + column

    def handle_starttag(
        self, tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        if self._section_depth:
            if tag == "section":
                self._section_depth += 1
            return

        attrs_dict = dict(attrs)
        if tag == "section" and attrs_dict.get("role") == "doc-endnotes":
            self._range_start = self._absolute_position()
            self._section_depth = 1

    def handle_endtag(self, tag: str) -> None:
        if not self._section_depth or tag != "section":
            return

        self._section_depth -= 1
        if self._section_depth:
            return

        end_tag_start = self._absolute_position()
        end = self.html_text.find(">", end_tag_start)
        if end == -1 or self._range_start is None:
            raise ValueError("无法确定 Typst 文末脚注的 HTML 边界")
        self.ranges.append((self._range_start, end + 1))
        self._range_start = None

    def finish(self) -> list[tuple[int, int]]:
        if self._section_depth or self._range_start is not None:
            raise ValueError("Typst 文末脚注的 <section> 未闭合")
        return self.ranges


def strip_exported_endnotes(html_text: str) -> tuple[str, int]:
    """Remove exporter endnotes; footnotes are already rendered as sidenotes."""
    locator = ExportedEndnotesLocator(html_text)
    locator.feed(html_text)
    locator.close()
    ranges = locator.finish()
    for start, end in reversed(ranges):
        html_text = html_text[:start] + html_text[end:]
    return html_text, len(ranges)


def finalize_html_output(html_path: Path, page_path: str) -> bool:
    """Finalize injected head elements and the site's sidenote-only footnotes."""
    try:
        html_text = html_path.read_text(encoding="utf-8")
        staged = HEAD_STAGING_RE.search(html_text)
        if staged is None:
            # Typst may leave an unchanged target in place when a dependency
            # edit does not alter the exported document. In that case the
            # existing target has already passed through this function.
            if FINALIZED_HEAD_MARKER not in html_text:
                print(f"  ❌ 未找到待注入的 head 元素: {html_path}")
                return False
            finalized, _ = strip_exported_endnotes(html_text)
            if finalized != html_text:
                html_path.write_text(finalized, encoding="utf-8")
            return True

        parser = HTMLMetadataParser()
        parser.feed(html_text)
        title = parser.metadata.get("title", "").strip()
        description = parser.metadata.get("description", "").strip()
        author = parser.metadata.get("author", "").strip()
        canonical_url = parser.metadata.get("link", "").strip()
        og_type = "website" if page_path in {"", "/"} else "article"

        seo = [
            f'<meta property="og:title" content="{escape_html(title, quote=True)}">',
            f'<meta property="og:type" content="{og_type}">',
        ]
        if description:
            seo.append(
                f'<meta property="og:description" content="{escape_html(description, quote=True)}">'
            )
        if canonical_url:
            seo.append(
                f'<meta property="og:url" content="{escape_html(canonical_url, quote=True)}">'
            )
        if author and og_type == "article":
            seo.append(
                f'<meta property="article:author" content="{escape_html(author, quote=True)}">'
            )

        head_content = staged.group(1) + "".join(seo)
        html_text = HEAD_STAGING_RE.sub("", html_text, count=1)
        if "</head>" not in html_text:
            print(f"  ❌ HTML 缺少 </head>: {html_path}")
            return False
        html_text = html_text.replace("</head>", head_content + "</head>", 1)
        html_text, _ = strip_exported_endnotes(html_text)
        html_path.write_text(html_text, encoding="utf-8")
        return True
    except Exception as e:
        print(f"  ❌ HTML 后处理失败: {e}")
        return False


def build_html(force: bool = False) -> bool:
    """
    编译所有 .typ 文件为 HTML（文件名中包含 PDF 的除外）。

    参数:
        force: 是否强制重建所有文件
    """
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    if not generate_blog_manifest():
        return False

    typ_files = find_typ_files()

    # 排除标记为 PDF 的文件
    html_files = [f for f in typ_files if "pdf" not in f.stem.lower()]

    if not html_files:
        print("  ⚠️ 未找到任何 HTML 文件。")
        return True

    print("正在构建 HTML 文件...")

    # 获取公共依赖
    common_deps = find_common_dependencies()

    def get_page_path(typ_file: Path) -> str:
        try:
            rel_path = typ_file.relative_to(CONTENT_DIR)

            if rel_path.name == "index.typ":
                # index.typ uses the parent directory name as the path
                # content/Blog/index.typ -> "Blog"
                # content/index.typ -> "" (Homepage)
                page_path = rel_path.parent.as_posix()
                if page_path == ".":
                    page_path = ""
            else:
                # Common files use the filename as the path
                # content/about.typ -> "about"
                page_path = rel_path.with_suffix("").as_posix()
        except ValueError:
            page_path = ""

        return page_path

    def build_html_args(typ_file: Path, output_path: Path) -> list[str]:
        """构建 HTML 编译参数"""
        page_path = get_page_path(typ_file)

        return [
            "compile",
            "--root",
            ".",
            "--font-path",
            str(ASSETS_DIR),
            "--features",
            "html",
            "--format",
            "html",
            "--input",
            f"page-path={page_path}",
            str(typ_file),
            str(output_path),
        ]

    stats = _compile_files(
        html_files,
        force,
        common_deps,
        lambda typ_file: get_file_output_path(typ_file, "html"),
        build_html_args,
        lambda typ_file, output_path: finalize_html_output(
            output_path, get_page_path(typ_file)
        ),
    )

    print(f"✅ HTML 构建完成。{stats.format_summary()}")
    return not stats.has_failures


def build_pdf(force: bool = False) -> bool:
    """
    编译文件名包含 "PDF" 的 .typ 文件为 PDF。

    参数:
        force: 是否强制重建所有文件
    """
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    typ_files = find_typ_files()
    pdf_files = [f for f in typ_files if "pdf" in f.stem.lower()]

    if not pdf_files:
        return True

    print("正在构建 PDF 文件...")

    # 获取公共依赖
    common_deps = find_common_dependencies()

    def build_pdf_args(typ_file: Path, output_path: Path) -> list[str]:
        """构建 PDF 编译参数"""
        return [
            "compile",
            "--root",
            ".",
            "--font-path",
            str(ASSETS_DIR),
            str(typ_file),
            str(output_path),
        ]

    stats = _compile_files(
        pdf_files,
        force,
        common_deps,
        lambda typ_file: get_file_output_path(typ_file, "pdf"),
        build_pdf_args,
    )

    print(f"✅ PDF 构建完成。{stats.format_summary()}")
    return not stats.has_failures


def copy_assets() -> bool:
    """
    复制静态资源到输出目录。
    """
    if not ASSETS_DIR.exists():
        print(f"  ⚠ 静态资源目录 {ASSETS_DIR} 不存在。")
        return True

    SITE_DIR.mkdir(parents=True, exist_ok=True)
    target_dir = SITE_DIR / "assets"

    try:
        if target_dir.exists():
            shutil.rmtree(target_dir)
        shutil.copytree(ASSETS_DIR, target_dir)
        return True
    except Exception as e:
        print(f"  ❌ 复制静态资源失败: {e}")
        return False


def copy_content_assets(force: bool = False) -> bool:
    """
    复制 content 目录下的非 .typ 文件（如图片）到输出目录。
    支持增量复制：只复制修改过的文件。

    参数:
        force: 是否强制复制所有文件
    """
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    if not CONTENT_DIR.exists():
        print(f"  ⚠ 内容目录 {CONTENT_DIR} 不存在，跳过。")
        return True

    try:
        copy_count = 0
        skip_count = 0

        for item in CONTENT_DIR.rglob("*"):
            # 跳过目录和 .typ 文件
            if item.is_dir() or item.suffix == ".typ":
                continue

            # 跳过以下划线开头的路径
            relative_path = item.relative_to(CONTENT_DIR)
            if any(part.startswith("_") for part in relative_path.parts):
                continue

            # 计算目标路径
            target_path = SITE_DIR / relative_path

            # 增量复制检查
            if not force and target_path.exists():
                if get_file_mtime(item) <= get_file_mtime(target_path):
                    skip_count += 1
                    continue

            # 创建目标目录
            target_path.parent.mkdir(parents=True, exist_ok=True)

            # 复制文件
            shutil.copy2(item, target_path)
            copy_count += 1

        return True
    except Exception as e:
        print(f"  ❌ 复制内容资源文件失败: {e}")
        return False


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


def parse_html_metadata(html_path: Path) -> dict[str, str]:
    """
    解析 HTML 文件并返回元数据解析器实例。

    参数:
        html_path (Path): HTML 文件路径

    返回:
        HTMLMetadataParser: 包含解析结果的解析器实例
    """
    parser = HTMLMetadataParser()
    parser.feed(html_path.read_text(encoding="utf-8"))
    return parser.metadata


def get_site_url() -> str | None:
    """
    从生成的首页 HTML 文件中解析站点 URL。

    功能:
        从 _site/index.html 的 <link rel="canonical" href="..."> 提取 site-url。

    返回:
        str: 站点的根 URL（如 "https://example.com"），末尾不带斜杠。
            如果未配置或解析失败则返回 None。
    """
    index_html = SITE_DIR / "index.html"
    parser = parse_html_metadata(index_html)

    if parser.get("link"):
        return parser["link"].rstrip("/")

    return None


def get_feed_dirs() -> set[str]:
    """
    从 config.typ 配置文件中解析 RSS Feed 订阅源的配置信息。

    功能:
        解析 config.typ 中的 feed 配置块，提取目录列表。

    返回:
        set[str]: 要包含的文章目录列表，默认为空集合
    """
    if not CONFIG_FILE.exists():
        return set()

    try:
        content = CONFIG_FILE.read_text(encoding="utf-8")

        # 移除注释
        content = re.sub(r"//.*", "", content)
        content = re.sub(r"/\*[\s\S]*?\*/", "", content)

        match = re.search(r"feed-dir\s*:\s*\((.*?)\)", content, re.DOTALL)
        if match:
            return {
                c.strip("/") if c.strip("/") else "/"
                for c in re.findall(r'"([^"]*)"', match.group(1))
                if c
            }
    except Exception as e:
        print(f"⚠️ 解析 feed-dir 失败: {e}")

    return set()


def extract_post_metadata(index_html: Path) -> tuple[str, str, str, datetime | None]:
    """
    从生成的 HTML 文件中提取文章的元数据信息。

    功能:
        提取文章元数据：
        1. 标题 (title): 从 <title> 标签提取
        2. 描述 (description): 从 <meta name="description"> 提取
        3. 链接 (link): 从 <link rel="canonical" href="..."> 提取
        4. 日期 (date): 依次尝试从以下来源获取：
            - HTML 中的 <meta name="date" content="...">
            - 文件夹名中的 YYYY-MM-DD 格式日期

    参数:
        index_html (Path): 文章的 index.html 文件路径

    返回:
        tuple[str, str, str, datetime | None]: 包含四个元素的元组：
            - str: 文章标题
            - str: 文章描述（可能为空字符串）
            - str: 文章链接（完整 URL）
            - datetime | None: 文章日期（带 UTC 时区），无法获取时为 None
    """
    parser = parse_html_metadata(index_html)

    title = parser["title"].strip()
    description = parser.get("description", "").strip()
    link = parser.get("link", "")
    date_obj = None

    # 尝试从 <meta name="date"> 解析日期
    if parser.get("date"):
        try:
            date_obj = datetime.strptime(parser["date"].split("T")[0], "%Y-%m-%d")
            date_obj = date_obj.replace(tzinfo=timezone.utc)
        except Exception:
            pass

    # 如果没找到日期，尝试从文件夹名提取 (YYYY-MM-DD)
    if not date_obj:
        date_match = re.search(r"(\d{4}-\d{2}-\d{2})", index_html.parent.name)
        if date_match:
            try:
                date_obj = datetime.strptime(date_match.group(1), "%Y-%m-%d")
                date_obj = date_obj.replace(tzinfo=timezone.utc)
            except ValueError:
                pass

    return title, description, link, date_obj


def collect_posts(dirs: set[str], site_url: str) -> list[dict]:
    """
    从指定的目录中收集所有文章的元数据。

    功能:
        遍历 _site 目录下指定目录中的所有子目录，提取每个文章的元数据信息。
        只处理目录（每个目录代表一篇文章），跳过普通文件。
        如果无法确定文章日期，则跳过该文章并输出警告。

    参数:
        dirs (set[str]): 要扫描的目录名称集合（如 {"Blog", "Docs"}）
        site_url (str): 站点的根 URL（如 "https://example.com"）

    返回:
        list[dict]: 文章数据字典列表，每个字典包含以下键：
            - title (str): 文章标题
            - description (str): 文章描述
            - dir (str): 文章所属分类（即目录名）
            - link (str): 文章的完整 URL
            - date (datetime): 文章日期对象（带时区）
    """
    posts = []

    for d in dirs:
        dir_path = SITE_DIR if d in ("/", "") else SITE_DIR / d
        if not dir_path.exists():
            continue

        for index_html in sorted(dir_path.rglob("index.html")):
            title, description, link, date_obj = extract_post_metadata(index_html)

            if not date_obj:
                continue

            rel_parts = index_html.relative_to(SITE_DIR).parts
            posts.append(
                {
                    "title": title,
                    "description": description,
                    "dir": rel_parts[0] if rel_parts else d,
                    "link": link,
                    "date": date_obj,
                }
            )

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
    """
    生成网站的 RSS 订阅源文件。

    功能:
        完整的 RSS Feed 生成流程：
        1. 从 config.typ 读取目标目录（分类）
        2. 收集指定目录下的所有文章元数据
        3. 按日期排序
        4. 构建 RSS XML 并写入文件

    返回:
        bool: 生成是否成功。在以下情况返回 True：
            - 成功生成 RSS 文件
            - 未找到任何分类目录（跳过生成）
            - 未找到任何文章（生成空 Feed）
        仅在发生异常时返回 False。
    """
    rss_file = SITE_DIR / "feed.xml"
    dirs = get_feed_dirs()

    if not dirs:
        print("⚠️ 跳过 RSS 订阅源生成: 未配置任何目录。")
        return True

    # 检查是否至少有一个目录存在
    existing = {
        d for d in dirs if (SITE_DIR if d in ("/", "") else SITE_DIR / d).exists()
    }
    missing = dirs - existing

    for d in missing:
        print(f"⚠️ 警告: 配置的目录 '{d}' 不存在。")

    if not existing:
        print("⚠️ 跳过 RSS 订阅源生成: 配置的目录都不存在。")
        return True

    # 收集文章
    posts = collect_posts(existing, site_url)

    if not posts:
        print("⚠️ 未找到任何文章，RSS 订阅源为空。")
        return True

    # 按日期降序排序
    posts = sorted(posts, key=lambda x: x["date"], reverse=True)

    # 获取配置信息
    index_html = SITE_DIR / "index.html"
    parser = parse_html_metadata(index_html)

    lang = parser["lang"]
    site_title = parser["title"].strip()
    site_description = parser.get("description", "").strip()

    config = {
        "site_url": site_url,
        "site_title": site_title,
        "site_description": site_description,
        "lang": lang,
    }

    # 构建 RSS XML
    try:
        rss_content = build_rss_xml(posts, config)
        rss_file.write_text(rss_content, encoding="utf-8")
        print(f"✅ RSS 订阅源生成成功: {rss_file} ({len(posts)} 篇文章)")
        return True
    except ValueError as e:
        print("❌ 错误: RSS 订阅源生成失败")
        print(f"   原因: feedgen 库报错 - {e}")
        print("   解决: 请检查 config.typ 中的必需配置字段（title 和 description）")
        return False
    except Exception as e:
        print("❌ 错误: 生成 RSS 订阅源时出错")
        print(f"   异常: {type(e).__name__}: {e}")
        return False


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

    if rel_path == Path("Blog/index.html"):
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
    blog_index_source: Path | None = None
    blog_index_lastmod: str | None = None

    try:
        # 遍历 _site 目录
        for file_path in sorted(SITE_DIR.rglob("*.html")):
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
            if rel_path == "Blog/index.html":
                blog_index_source = source_path
                blog_index_lastmod = lastmod

            # 创建 url 元素
            url_elem = ET.SubElement(urlset, "url")
            ET.SubElement(url_elem, "loc").text = full_url
            ET.SubElement(url_elem, "lastmod").text = lastmod
    except RuntimeError as e:
        print(f"❌ Sitemap 构建失败: {e}")
        return False

    if blog_index_source is not None:
        print(
            "ℹ️ Blog/index.html lastmod: "
            f"{blog_index_lastmod}（按发布日期选择最新文章 "
            f"{blog_index_source.as_posix()}）"
        )

    # 生成 XML 字符串
    ET.indent(urlset, space="  ")
    xml_str = ET.tostring(urlset, encoding="unicode", xml_declaration=False)
    sitemap_content = f'<?xml version="1.0" encoding="UTF-8"?>\n{xml_str}'

    try:
        sitemap_path.write_text(sitemap_content, encoding="utf-8")
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
        (SITE_DIR / "robots.txt").write_text(robots_content, encoding="utf-8")
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
        redirects_file.write_text("\n".join(rules) + "\n", encoding="utf-8")
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
        clean()
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
    print()

    results.append(copy_assets())
    results.append(copy_content_assets(force))
    results.append(generate_cloudflare_redirects())

    if site_url := get_site_url():
        results.append(generate_sitemap(site_url))
        results.append(generate_robots_txt(site_url))
        results.append(generate_rss(site_url))

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

    if args.command in {"build", "html", "pdf"}:
        warn_if_typst_version_is_outdated()

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
