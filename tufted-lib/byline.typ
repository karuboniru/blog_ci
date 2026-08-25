#import "tags.typ": tag-id

/// Render article metadata below the document title.
#let article-byline(author: none, date: none, tag: (), extra-info: none) = {
  let tags = if type(tag) == str { (tag,) } else { tag }

  let formatted-date = if date != none {
    if type(date) == datetime {
      (display: date.display(), datetime: date.display())
    } else {
      (display: date, datetime: none)
    }
  } else {
    (display: none, datetime: none)
  }

  html.div(
    class: "article-byline",
    {
      if author != none or date != none {
        html.p(
          class: "article-byline-main",
          {
            if author != none {
              html.span(class: "article-author", author)
            }
            if author != none and date != none {
              html.span(class: "article-byline-separator", " · ")
            }
            if date != none {
              let attrs = if formatted-date.datetime != none {
                (class: "article-date", datetime: formatted-date.datetime)
              } else {
                (class: "article-date")
              }

              html.elem("time", attrs: attrs, formatted-date.display)
            }
          },
        )
      }

      if tags.len() > 0 {
        html.p(
          class: "article-extra-info",
          {
            [标签：]
            for (index, name) in tags.enumerate() {
              if index > 0 {
                [ · ]
              }
              html.a(href: "/Tag/#" + tag-id(name), name)
            }
          },
        )
      }

      if extra-info != none {
        html.p(class: "article-extra-info", extra-info)
      }
    },
  )
}

/// Inject article metadata once, directly below the document title.
#let template-byline(content, author: none, date: none, tag: (), extra-info: none) = {
  let tags = if type(tag) == str { (tag,) } else { tag }

  if date != none or tags.len() > 0 or extra-info != none {
    let injected = state("article-byline-injected", false)

    show title: it => {
      it
      context {
        if not injected.get() {
          injected.update(true)
          article-byline(
            author: author,
            date: date,
            tag: tags,
            extra-info: extra-info,
          )
        }
      }
    }

    content
  } else {
    content
  }
}
