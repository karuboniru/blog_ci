# Karuboniru's Blog

这里是 [Karuboniru 的个人博客](https://niconi.org/) 的源代码仓库。

博客基于 [Typst](https://typst.app/) 和 [Tufted](https://github.com/vsheg/tufted) 构建，并沿用了 [Tufted Blog Template](https://github.com/Yousa-Mirage/Tufted-Blog-Template) 的构建方式和样式。

## 本地构建

项目需要 Typst 0.15.1 或更新版本和 Python 3.10+。推荐使用 [uv](https://docs.astral.sh/uv/) 运行构建脚本：

```bash
uv run build.py build
```

也可以直接使用 Python：

```bash
python build.py build
```

构建结果会输出到 `_site/`。本地预览可运行：

```bash
uv run build.py preview
```

## 构建流程

- Typst 模板直接生成完整 HTML，包括 head、SEO 元数据和旁注；Python 不改写 HTML。
- 模板通过 `<tufted-page>` metadata 暴露页面数据。构建脚本使用 `typst eval` 读取并校验 JSON，生成 RSS 和 sitemap，不解析 `.typ` 源码或从 HTML 反读元数据。
- 增量构建使用 `typst compile --deps` 的实际依赖和内容哈希，覆盖动态导入、资源及包依赖；编译器、构建脚本、参数、字体路径或相关环境变化也会使缓存失效。
- 缓存保存在 `.build-cache/`，不进入网站。编译和元数据校验成功后才替换页面；失败保留该页面上次成功的产物。完整构建失败时应停止部署。
- 编译前后校验依赖的内容哈希与文件状态，覆盖 HTML 编译和 metadata 求值的整个过程。首次发现依赖或构建期间保存文件会触发重试，最多尝试三次；持续变化时构建失败，不发布不一致的页面或缓存。
- 每个构建阶段维护输出清单，删除不再对应源文件的旧页面与资源。RSS/sitemap 只使用当前源文件清单。
- `--force` 强制重新编译，但不先删除现有产物；`clean` 用于显式清空 `_site/`。

文章继续使用现有的 `post` 字典和 `#show: template.with(..post)`。富文本标题在正文保留格式，head 和 JSON 共用 `tufted-lib/plain-text.typ` 的结构化内容转换。

回归检查：

```bash
python -m unittest discover -s tests
node --test tests/sidenote-layout.test.mjs
python tests/compare_builds.py /path/to/baseline _site
```

产物比较会检查 HTML 正文、head 内容和脚本/链接顺序，比较 RSS（忽略构建时间）与其余静态产物，并使用 Poppler 比较 PDF 文本和逐页像素。HTML 比较允许旧导出器遗留的、未被引用的脚注 `loc-*` 锚点消失；数学样式的插入顺序变化另需浏览器布局回归。

## 许可

- **代码**：沿用上游项目原有的 [MIT License](LICENSE)。
- **文章**：除非另有说明，博客文章采用 [Creative Commons Attribution-ShareAlike 4.0 International（CC BY-SA 4.0）](https://creativecommons.org/licenses/by-sa/4.0/) 许可。

转载文章时请注明作者与原文链接，并以相同许可方式分享演绎内容。
