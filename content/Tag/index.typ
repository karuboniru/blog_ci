#import "../../config.typ": template, tufted
#import "../Blog/_posts.typ": post-sources

#show: template.with(
  title: [标签 / Tags],
  description: [Karuboniru 的博客标签归档],
)

#title()

#let posts = post-sources.map(source => {
  let article-source = "../Blog/" + source.source
  import article-source as article
  article.post + (path: "/Blog/" + source.path,)
})

#let post-tags(post) = {
  let tag = post.at("tag", default: ())
  if type(tag) == str { (tag,) } else { tag }
}

#let tags = posts.fold(
  (),
  (tags, post) => tags + post-tags(post),
).dedup().sorted()

#for tag in tags {
  let tagged-posts = posts.filter(
    post => post-tags(post).contains(tag),
  ).sorted(key: post => post.date).rev()

  html.div(
    class: "tag-group",
    html.details(
      name: "tags",
      open: false,
      {
        html.summary(tag + " (" + str(tagged-posts.len()) + ")")
        for post in tagged-posts {
          tufted.blog-entry(
            date: post.date,
            path: post.path,
            title: post.title,
          )
        }
      },
    ),
  )
}
