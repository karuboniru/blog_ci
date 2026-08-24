#import "../../../../index.typ": template, tufted
// 原文件: source/_posts/building.md
// 原文时间: 2020-03-30 13:11:58
// tags: 记录
#show: template.with(
  title: "博客创建过程与总结",
  date: datetime(year: 2020, month: 3, day: 30),
  extra-info: "标签：记录",
  comments: true,
)

= 博客创建过程与总结

至此, 博客建站算是完成了, 整个过程历时三天, 由于一些强迫症修各种细节花了我不少时间.

== 主题
本站使用的主题是 #link("https://github.com/karuboniru/hexo-theme-fluid")[我改过的 fluid], 改动可以看链接里面的 #link("https://github.com/karuboniru/hexo-theme-fluid")[commits], 其中有些改动已经提了 Pull Request 并且已经被接受, 但是还有一些并非 bug 修复或者是改进, 只是个人喜好, 于是就不 PR 了.

我的版本的 fluid 相对 #link("https://github.com/fluid-dev/hexo-theme-fluid")[原版] 改动(没有合并进入 master 的)有以下 :

- 添加了 PWA 支持, 本站现在是 PWA 网站, 你甚至可以作为应用安装它;
- #strike[尽可能使用 #link("https://cdnjs.com/")[cdnjs] 作为静态脚本来源, 这是为了即将到来的 HTTP/3 做准备, 静态资源来自同一个源能借助 0-RTT加速访问;] 换成了 jsdelivr, CDNjs 太慢了, jsdelivr 在全球都有节点, 是好东西.
- #strike[修复了统计相关的(可能影响加载速度的)一个轻微 bug, 合并到了原项目的 dev 分支.]\(也进入master了)
- MathJax 升级到 MathJax 3.0.1, 加载及渲染更快.

因为一些静态资源被我放到了站点内部, 于是大家想要使用我修改之后的主题需要一并带上 `source/css` 里面的东西. #strike[真的有人会用吗?]

但是真的有人想用的话可以直接 fork #link("https://github.com/karuboniru/blog_ci")[blog\_ci] 仓库, 改下配置文件和持续集成脚本, 设置好 secrets, 应该就能用了.

=== 文章页面 banner 随机图片
banner 接口用的是 #link("https://www.52ecy.cn/post-125.html")[阿珏博客] 提供的 API. 使用超级简单, 感谢大佬.

== PWA
本站有完全的 PWA #link("https://googlechrome.github.io/lighthouse/viewer/?psiurl=https%3A%2F%2Fyanqiyu.info%2F&strategy=desktop&category=performance&category=accessibility&category=best-practices&category=seo&category=pwa&utm_source=lh-chrome-ext#pwa")[支持]:

#html.img(src: "https://cdn.yanqiyu.info/2020-03-30-130142.webp")

PWA 支持是由 #link("https://github.com/JLHwung/hexo-offline")[hexo-offline] 包提供的代码. PWA 意味着只要加载过, 缓存还在, 之后加载就会很快

== 持续集成
本站使用 #link("https://hexo.io")[Hexo], 作为静态网站, 需要从 Markdown 生成 HTML. 为了方便到处写东西而不需要使用电脑, 于是我#strike[白嫖]使用了 #link("https://github.com/features/actions")[GitHub Actions], 对于项目源代码分割成了三个仓库:

- #link("https://github.com/karuboniru/hexo-theme-fluid")[主题]
- #link("https://github.com/karuboniru/blog_md")[文章]: 每次 push 触发更新 Hexo 工作区的 `submodule` 并push, 并触发 Hexo 工作区的持续集成;
- #link("https://github.com/karuboniru/blog_ci")[Hexo 工作区]: 每次 push 更新网页.

然后每次添加文章只需要修改 #link("https://github.com/karuboniru/blog_md")[文章] 这个仓库就能保证其他东西跟着更新了. 但是主题不做持续集成是因为给我觉得修改主题的事情还是先本地看下效果为好, 免得翻车.

由于层层缓存的存在, 更新需要数分钟才能被看到, 我也没得法, 我也懒得管.

== 写东西
写东西就用神奇的 #link("https://typora.io/")[Typora], 支持所见即所得的 Markdown 编辑器, 这个我要安利一波! 甚至于可以用来做课堂笔记!

== 奇妙的 BUG
在这里 `hexo-asset-image` 不能正确地生成图片链接, 要换成 `hexo-asset-image-fix`. 这是我全程遇到的最奇妙的 BUG 了.

本文也算不上是教程, 之所以我不写教程是因为网上大多有相关教程, 魔改主题这件事情我也是新手, 基本是猜着语法改, 也没与可学习的.
