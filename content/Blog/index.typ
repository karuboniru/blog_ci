#import "../../config.typ": template, tufted
#import "_posts.typ": post-sources

#show: template.with(
  title: [博客 / Blog],
  description: [Karuboniru 的博客归档],
)

#title()

#let posts = post-sources.map(source => {
  import source.source as article
  article.post + (path: source.path,)
}).sorted(key: post => post.date).rev()

#for year in posts.map(post => post.date.year()).dedup() {
  heading(level: 1, str(year))
  for post in posts.filter(post => post.date.year() == year) {
    tufted.blog-entry(
      date: post.date,
      path: post.path,
      title: post.title,
    )
  }
}
