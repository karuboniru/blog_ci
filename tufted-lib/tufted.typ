#import "math.typ": template-math
#import "refs.typ": template-refs
#import "notes.typ": template-notes
#import "figures.typ": template-figures
#import "blog-entry.typ": blog-entry
#import "layout.typ": full-width, margin-note
#import "links.typ": template-links
#import "metadata.typ": metadata
#import "byline.typ": template-byline
#import "comments.typ": waline-comments
#import "plain-text.typ": plain-text

/// The main wrapper function of Tufted Blog Template.
///
/// Typst owns the complete HTML document and exports structured build metadata.
#let tufted-web(
  header-links: (:),

  // Document metadata
  title: none,
  author: none,
  description: none,
  lang: "zh",
  date: none,
  tag: (),
  extra-info: none,
  website-title: "",
  website-url: none,

  // For SEO
  image-path: none,

  // For RSS
  feed-dir: (),

  // Custom header and footer
  header-elements: (),
  footer-elements: (),

  // Custom CSS and JS scripts
  css: ("/assets/custom.css",),
  js-scripts: (),
  head-elements: (),

  // Waline comments
  comments: false,

  content,
) = {
  set document(
    title: title,
    author: if author == none { () } else { author },
    description: description,
    date: if type(date) == datetime { date } else { none },
  )
  set text(lang: lang)

  show: template-math
  show: template-refs
  show: template-notes
  show: template-figures
  show: template-links
  show: template-byline.with(
    author: author,
    date: date,
    tag: tag,
    extra-info: extra-info,
  )

  context {
    let page-path = sys.inputs.at("page-path", default: "")
    let canonical = if website-url == none { "" } else {
      website-url.trim("/", at: end) + "/" + if page-path == "" { "" } else { page-path.trim("/") + "/" }
    }
    let page-data = (
      schema: 1,
      title: plain-text(document.title),
      description: plain-text(document.description),
      author: document.author.join(", ", default: ""),
      lang: lang,
      date: if type(date) == datetime { date.display() } else if date == none { "" } else { date },
      link: canonical,
      feed-dirs: if feed-dir == none { () } else { feed-dir },
    )
    [#std.metadata(page-data) <tufted-page>]

    html.html(lang: lang, {
      html.head({
        html.meta(charset: "utf-8")
        html.meta(name: "viewport", content: "width=device-width, initial-scale=1")
        if document.title != none { html.title(page-data.title) }
        if document.description != none { html.meta(name: "description", content: page-data.description) }
        if page-data.author != "" { html.meta(name: "authors", content: page-data.author) }
        if document.keywords.len() > 0 {
          html.meta(name: "keywords", content: document.keywords.join(", "))
        }
        metadata(
          date: date,
          website-title: website-title,
          website-url: website-url,
          image-path: image-path,
          feed-dir: feed-dir,
          canonical-url: canonical,
        )

        let base-css = (
          "https://cdnjs.cloudflare.com/ajax/libs/tufte-css/1.8.0/tufte.min.css",
          "/assets/tufted.css",
          "/assets/theme.css",
        )
        for css-link in (base-css + css).dedup() {
          html.link(rel: "stylesheet", href: css-link)
        }

        let base-js = (
          "/assets/service-worker.js",
          "/assets/code-blocks.js",
          "/assets/format-headings.js",
          "/assets/theme-toggle.js",
          "/assets/marginnote-toggle.js",
          "/assets/toc.js",
          "/assets/back-to-top.js",
          "/assets/math-copy.js",
        )
        for js-src in (base-js + js-scripts).dedup() {
          html.script(src: js-src)
        }
        html.script(type: "module", src: "/assets/sidenote-layout.mjs")

        for element in head-elements {
          element
        }
        let og-type = if page-path in ("", "/") { "website" } else { "article" }
        html.elem("meta", attrs: (property: "og:title", content: page-data.title.trim()))
        html.elem("meta", attrs: (property: "og:type", content: og-type))
        if page-data.description.trim() != "" {
          html.elem("meta", attrs: (property: "og:description", content: page-data.description.trim()))
        }
        if canonical != "" {
          html.elem("meta", attrs: (property: "og:url", content: canonical))
        }
        if page-data.author.trim() != "" and og-type == "article" {
          html.elem("meta", attrs: (property: "article:author", content: page-data.author.trim()))
        }
      })

      html.body({
        html.header(
          class: "site-header",
          {
            for (i, element) in header-elements.enumerate() {
              element
              if i < header-elements.len() - 1 {
                html.br()
              }
            }
          },
        )

        html.header(
          class: "site-header",
          if header-links != none {
            html.nav(
              class: "site-nav",
              {
                for (href, link-title) in header-links {
                  html.a(href: href, link-title)
                }
                html.elem(
                  "button",
                  attrs: (
                    id: "theme-toggle",
                    class: "theme-toggle-btn",
                    type: "button",
                    aria-label: "Toggle theme",
                  ),
                  "",
                )
              },
            )
          },
        )

        html.article(html.section(content))

        if comments {
          waline-comments()
        }

        html.footer({
          for (i, element) in footer-elements.enumerate() {
            element
            if i < footer-elements.len() - 1 {
              html.br()
            }
          }
        })
      })
    })
  }
}
