/// Produce additional metadata directly inside the document head.
#let metadata(
  date: none,
  website-title: "",
  website-url: none,
  image-path: none,
  feed-dir: (),
  canonical-url: "",
) = {
  html.meta(name: "generator", content: "Typst")
  html.link(rel: "icon", href: "https://cdn.yanqiyu.info/2026/08/24/logo.webp")

  if type(date) == datetime {
    html.meta(name: "date", content: date.display())
  } else if type(date) == str {
    html.meta(name: "date", content: date)
  }

  if feed-dir != none and feed-dir.len() > 0 {
    let rss-title = if type(website-title) == str and website-title != "" {
      website-title + " RSS Feed"
    } else {
      "RSS Feed"
    }
    html.link(
      rel: "alternate",
      type: "application/rss+xml",
      href: "/feed.xml",
      title: rss-title,
    )
  }

  if canonical-url != "" {
    html.link(rel: "canonical", href: canonical-url)
  }

  let og-image = if image-path == none {
    none
  } else if image-path.starts-with("http") {
    image-path
  } else if website-url != none {
    website-url.trim("/", at: end) + "/" + image-path.trim("/", at: start)
  } else {
    none
  }

  if og-image != none {
    html.elem("meta", attrs: (property: "og:image", content: og-image))
    html.meta(name: "twitter:card", content: "summary_large_image")
    html.meta(name: "twitter:image", content: og-image)
  } else {
    html.meta(name: "twitter:card", content: "summary")
  }
}
