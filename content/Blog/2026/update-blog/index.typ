#import "../../../../config.typ": template, tufted
#let post = (
  title: [绝妙的Typst博客框架],
  date: datetime(year: 2026, month: 8, day: 25),
  comments: true,
)
#show: template.with(..post)

#title()

= 背景故事

其实在很早之前我就用上了Typst来处理日常的排版任务，其相对于LaTeX带来了很多便利#footnote[
  好处是快，以及写错了能正确的报错，复杂的逻辑在Typst要阳间不少。
  代价是完全没有PostScript支持了，只能回到PDF来处理图像，不过支持PDF我就很感恩了——因为很早之前Typst甚至只支持svg的矢量图。
]，尤其是在日常文档编排期间，Typst提供了绝妙的编程手段实现大量编排自动化产生的图像和从原始数据生成表格，以便阅读。
成了Typst的熟练工之后，我就进入了拿着锤子，看什么都是钉子的状态，只要不涉及协作和投稿的排版需求，我都会用Typst而不是LaTeX。

在 Typst 支持 HTML 导出之后，我就在琢磨博客的生成系统有没有可能从 Markdown 切换为 Typst。
但是受限于时间限制——毕业前后各种原因忙得团团转，于是一直没能实施。直到最近发现了一个各方面都满足我喜好的 Typst 博客框架：
#link("https://github.com/Yousa-Mirage/Tufted-Blog-Template")[
  Tufted-Blog-Template
]。于是干脆一不做二不休，直接把博客系统从 Hexo 换成了这么个方案。


= 解决的痛点
这个框架设计有个最大的好处是编译过程就是直接把所有Typst文件编译成路径对应的HTML文件，所需的工具链非常简单，不像 Hexo 那样需要 Node.js 及其引入的海量依赖包#footnote[
  我不是说Node.js不好，而是使用过程中遇到报错经常让人无法下手+想要修改依赖包的行为很麻烦。
]。并且清晰的结构很适合让AI上手实现我想要的功能。

= 迁移过程
迁移本身其实很简单，用 `pandoc` 逐个把 Hexo 的 Markdown 文件转换为 Typst 文件，然后让AI相应的补充Typst文件中需要的元数据和样式定义。不过日常的bug体质的我，迅速就发现了一些微妙的bug。
+ `quote-block` 等环境的数学公式排版字体莫名的大，并且宽度受限#footnote[#link("https://github.com/Yousa-Mirage/Tufted-Blog-Template/pull/43")[`Yousa-Mirage/Tufted-Blog-Template:43`]]
+ 移动端的目录页面被奇怪的压缩了#footnote[#link("https://github.com/Yousa-Mirage/Tufted-Blog-Template/pull/45")[`Yousa-Mirage/Tufted-Blog-Template:45`]]
+ 在表格、block、list等环境用 `#footnote` 生成的旁注对齐错误 #footnote[
    #link("https://github.com/Yousa-Mirage/Tufted-Blog-Template/pull/44")[`Yousa-Mirage/Tufted-Blog-Template:44`]
  
    这一条比较复杂，实际上把旁注改为了绝对定位，避免复杂的坐标计算出现bug。但是又因为绝对定位存在出现重叠的风险，又使用一个js脚本在页面加载时计算旁注的坐标，在不重叠的约束下用最小二乘目标函数计算出最优的坐标。
  ]
不过这些bug都不是问题——在开放人工智能研究中心 #sym.trademark 对话用生成式预训练转换器五点六太阳版#footnote[OpenAI ChatGPT 5.6-Sol]的帮助下——它们很容易就得到了解决。

此外，在#link("https://github.com/karuboniru/blog_ci")[本项目源代码]中，我还实现了一些纯粹因为个人喜好而进行的更改，这包括
- 迁移过来了评论系统
- 将源文件的结构改得更加符合Typst语义---比如文章标题应该通过 `set document(title: ...)` 来设置，并通过 `typst eval` 对外暴露
- 在前一条的基础上，实现了目录页的自动生成（`python` 脚本收集文件路径信息，Typst在一个循环中收集元数据并整理成目录页）
这些都没准备提交为PR，因为改动规模太大了，不过要是大伙感兴趣可以去我的仓库拣选。
