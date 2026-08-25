#import "../../config.typ": template, tufted
#import "../_data/links.typ": owner, links

#let friend-link(item) = {
  let avatar = item.at("avatar", default: none)
  let intro = item.at("intro", default: "")

  html.div(
    class: "friend-link-card",
    html.elem(
      "a",
      attrs: (href: item.url, class: "friend-link-body", target: "_blank", rel: "noopener"),
      [
        #if avatar != none [
          #html.div(
            class: "friend-link-avatar",
            html.img(src: avatar, alt: item.title, width: 48, height: 48, loading: "lazy", decoding: "async"),
          )
        ]
        #html.div(
          class: "friend-link-text",
          [
            #html.div(class: "friend-link-title", item.title)
            #html.div(class: "friend-link-intro", intro)
          ],
        )
      ],
    ),
  )
}

#show: template.with(
  title: [友情链接],
  description: [友情链接],
  comments: true,
)

#title()

交换友链，你可以直接在下面评论或者是在 #link("https://github.com/karuboniru/blog_ci")[这里] 提 issue。

= 我的信息

- 标题: #raw(owner.title)
- 链接: #raw(owner.url)
- 头像: #raw(owner.avatar)
- 简介: #owner.intro

= 友链

#html.div(
  class: "friend-links",
  {
    for item in links {
      friend-link(item)
    }
  },
)
