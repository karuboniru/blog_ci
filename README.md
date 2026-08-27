# Karuboniru's Blog

这里是 [Karuboniru 的个人博客](https://niconi.org/) 的源代码仓库。

博客基于 [Typst](https://typst.app/) 和 [Tufted](https://github.com/vsheg/tufted) 构建，并沿用了 [Tufted Blog Template](https://github.com/Yousa-Mirage/Tufted-Blog-Template) 的构建方式和样式。

## 本地构建

项目需要 Typst 和 Python。推荐使用 [uv](https://docs.astral.sh/uv/) 运行构建脚本：

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

## 许可

- **代码**：沿用上游项目原有的 [MIT License](LICENSE)。
- **文章**：除非另有说明，博客文章采用 [Creative Commons Attribution-ShareAlike 4.0 International（CC BY-SA 4.0）](https://creativecommons.org/licenses/by-sa/4.0/) 许可。

转载文章时请注明作者与原文链接，并以相同许可方式分享演绎内容。
