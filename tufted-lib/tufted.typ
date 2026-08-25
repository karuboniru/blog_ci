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

/// The main wrapper function of Tufted Blog Template.
///
/// Typst owns the document and its metadata. Elements that additionally belong
/// in the HTML head are staged in a template for build.py to move after export.
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

  // These elements are valid only in <head>. Keeping them in a template makes
  // the initial HTML inert and gives build.py an exact fragment to relocate.
  html.elem(
    "template",
    attrs: (data-tufted-head: ""),
    {
      metadata(
        date: date,
        website-title: website-title,
        website-url: website-url,
        image-path: image-path,
        feed-dir: feed-dir,
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
      html.elem(
        "script",
        attrs: (type: "module", src: "/assets/sidenote-layout.mjs", data-cfasync: "false"),
        "",
      )

      for element in head-elements {
        element
      }
    },
  )

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
}
