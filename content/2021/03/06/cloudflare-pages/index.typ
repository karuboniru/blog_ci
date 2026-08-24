#import "../../../../index.typ": template, tufted
// 原文件: source/_posts/cloudflare-pages.md
// 原文时间: 2021-03-06 11:53:53
// tags: 瞎折腾
// categories: 瞎折腾
#show: template.with(
  title: "我是来吹 Cloudflare Pages 的",
  date: datetime(year: 2021, month: 3, day: 6),
  image-path: "https://cdn.yanqiyu.info/20210306115901.png",
  extra-info: "标签：瞎折腾 | 分类：瞎折腾",
)

= 我是来吹 Cloudflare Pages 的

== 迁移博客到 Cloudflare Pages
#quote(block: true)[
薅羊毛，就要薅到底
]

#link("https://pages.dev/")[#html.img(src: "https://cdn.yanqiyu.info/20210306115901.png")]

突然发现 Cloudflare 的新静态网页托管服务结束了内测，变得可用。考虑到现在站点是 Github Pages + Cloudflare CDN 搭建，于是干脆一不做二不休换成 Cloudflare Pages 算了。 #strike[没有中间商赚差价] 我也不用粗暴的在每次 GitHub Actions 之后做一次缓存清除（以免 Cloudflare 缓存了旧的页面而没有及时更新）。

切换到 Cloudflare Pages 整体上很容易，在 #link("https://pages.dev/")[Pages] 页面点击那个大大的黄色的 Get Started 按钮，按照指引授权 GitHub 权限、选择构建使用的仓库、最后设置构建的命令就完成了迁移… 好吧，这是最简单的情况，适用于你的站点只需要最简单的命令即可构建时，例如下表中的框架：

#figure(
  align(center)[#table(
    columns: (31.11%, 38.89%, 30%),
    align: (auto,auto,auto,),
    table.header([框架], [构建命令], [输出目录],),
    table.hline(),
    [Angular (Angular CLI)], [`ng build`], [`dist`],
    [Brunch], [`brunch build --production`], [`public`],
    [Docusaurus], [`npm run build`], [`build`],
    [Eleventy], [`eleventy`], [`_site`],
    [Ember.js], [`ember build`], [`dist`],
    [Gatsby], [`gatsby build`], [`public`],
    [GitBook], [`gitbook build`], [`_book`],
    [Gridsome], [`gridsome build`], [`dist`],
    [Hugo], [`hugo`], [`public`],
    [Jekyll], [`jekyll build`], [`_site`],
    [Mkdocs], [`mkdocs build`], [`site`],
    [Next.js (Static HTML Export)], [`next build && next export`], [`out`],
    [Nuxt.js], [`nuxt generate`], [`dist`],
    [Pelican], [`pelican $content [-s settings.py]`], [`output`],
    [React (create-react-app)], [`npm run build`], [`build`],
    [React Static], [`react-static build`], [`dist`],
    [Slate], [`./deploy.sh`], [`build`],
    [Svelte], [`npm run build`], [`public`],
    [Umi], [`umi build`], [`dist`],
    [Vue], [`npm run build`], [`public`],
    [VuePress], [`vuepress build $directory`], [`$directory/.vuepress/dist`],
  )]
  , kind: table
  )

=== 我想要运行自定义脚本！
那你就放一个#link("https://github.com/karuboniru/blog_ci/blob/master/build.sh")[自定义脚本]在你的仓库里面呗。构建命令就是 `./build.sh`, 记得加上 `+x` 权限。你的脚本任务就是把网页源代码变成站点的文件放到特定文件夹，在 Pages 设置里面你需要指定输出文件夹的路径。

== 相对于使用 GitHub Actions 部署有什么好处/坏处？
一方面 GitHub Actions 更快，Cloudflare Pages 的服务有时候会莫名其妙的卡几分钟到几十分钟在 `正在初始化构建环境` 阶段。但是 Cloudflare Pages 能优雅的处理 Pull Request 并且#link("https://developers.cloudflare.com/pages/platform/preview-deployments")[提供预览页面]。

总之 Cloudflare 家大业大，并且是专门做网络服务的，做网页托管 #strong[应该] 不会太菜吧。

另外 Cloudflare 的那个 Proxy 对于他们自己托管的页面不好使，可以看 #link("https://discord.com/channels/595317990191398933/789155108529111069/817438688555827280")[discord 聊天记录]，但是之后会修。还有些别的可能的坑可以看看#link("https://developers.cloudflare.com/pages/platform/known-issues")[已知问题]。

== 关于网页跳转
虽然 CloudFlare Page #link("https://developers.cloudflare.com/pages/platform/redirects")[提供一定的跳转功能]，但是这个跳转不能跨域名。于是想要做一个 `www.yanqiyu.info` 到 `yanqiyu.info` 的跳转就需要借助 Worker 来完成。新建一个 Worker 填入

```javascript
const base = "https://yanqiyu.info"
const statusCode = 302
async function handleRequest(request) {  
  const url = new URL(request.url)  
  const { pathname, search } = url
  const destinationURL = base + pathname + search
  return Response.redirect(destinationURL, statusCode)
}

addEventListener("fetch", 
  async event => {  
    event.respondWith(handleRequest(event.request))
  }
)
```

记得把 `base` 改成你的域名。然后设置 route 把你想要跳转的域名指向这个 Worker 就成了。
