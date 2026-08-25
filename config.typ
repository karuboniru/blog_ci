#import "tufted-lib/tufted.typ" as tufted

/// 在 `config.typ` 中配置全局模板配置 template
/// 之后的每个页面都会从上个页面导入这个模板函数
/// 在每个具体页面中，都可以通过 `#show: template` 来应用模板
/// 也可以通过 `template.with(...)` 来覆盖某些配置项，从而为某个页面定制参数
#let template = tufted.tufted-web.with(
  /// 网站顶部导航栏的链接字典。格式为 `("链接地址": "显示名称")`。
  // 例如，如果你想添加一个 Entry 页，你需要添加 `"/Entry/": "Entry"`
  // 然后在 `content/` 路径中新建 `Entry/`路径，在其中添加 `index.typ` 作为 Entry 页的内容
  header-links: (
    "/": "首页",
    "/Blog/": "博客",
    "/Tag/": "标签",
    "/About/": "关于",
    "/Links/": "友链",
  ),

  /// 首页默认标题。
  title: [Karuboniru's Blog],

  /// 网站的站点标题。用于 RSS 等全站级元数据；页面标签标题来自上面的 title。
  website-title: "Karuboniru's Blog",
  /// 网站作者。用于生成文档作者元数据。（可选）
  author: "Karuboniru",
  /// 网站描述。用于 SEO 搜索引擎摘要和社交媒体分享预览。（可选）
  description: [就是个学物理的，懂个屁的计算机],
  /// 站点的根 URL (例如 "https://example.com")。用于生成 Canonical URL 元数据。（可选）
  website-url: "https://niconi.org/",
  /// 网站的默认语言，例如 "zh" 或 "en"，默认为 "zh"。
  lang: "zh",
  /// 订阅源配置 (字符串数组)，指定包含在 RSS 订阅源中的内容目录列表。（可选）
  /// 例如，`("/Blog/",)` 会将 `Blog` 目录下的所有文章包含在订阅源中。
  feed-dir: ("/Blog/",),
  
  /// 自定义页眉元素列表 (content 数组)。显示在页面顶部。
  header-elements: (
    [Karuboniru's Blog],
    // [就是个学物理的，懂个屁的计算机],
  ),
  /// 自定义页脚元素列表 (content 数组)，显示在页面底部。
  footer-elements: (
    [© Karuboniru, licensed under #link("https://creativecommons.org/licenses/by-sa/4.0/")[CC BY-SA 4.0]],
    [Powered by #link("https://github.com/Yousa-Mirage/Tufted-Blog-Template")[Tufted-Blog-Template]],
  ),
)

// 更多参数可参考网站配置文档。
