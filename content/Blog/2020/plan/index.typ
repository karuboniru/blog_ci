#import "../../../../config.typ": template, tufted
// 原文件: source/_posts/plan.md
// 原文时间: 2020-03-27 12:47:48
// math: true
#let post = (
  title: [规划],
  date: datetime(year: 2020, month: 3, day: 27),
  comments: true,
)
#show: template.with(..post)

#title()

因为万恶的知乎审查逐渐疯狂, 于是机智的我决定注销愚蠢的知乎, 转向使用美妙的 #link("https://hexo.io/")[Hexo].

之后准备闲下来的时候写点关于 #link("http://geant4.org/")[Geant4] 和 #link("https://root.cern/")[ROOT] 的文章, 也算是给后来人开路吧… 闲下来之后.

因为这里看起来支持 $upright(L a T e X)$, 可能会有一些物理的东西?

MathJax 实验: $mat(delim: "[", a, b; c, d)$, 不过评论区貌似有一些奇怪的 bug, 这是因为 markdown 的转义行为, 发表 $upright(L a T e X)$ 可以先预览一下看看是否踩坑.

Code Block 实验：

```
[ -1 ]
[ 2 ]
```
