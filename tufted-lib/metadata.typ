/// Produce head-only elements inside a staging template.
///
/// Typst owns the actual document head and serializes document metadata,
/// including rich document titles, to the plain-text forms required by HTML.
/// build.py moves this fragment into that generated head afterwards.
#let metadata(
  date: none,
  website-title: "",
  website-url: none,
  image-path: none,
  feed-dir: (),
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

  let page-path = sys.inputs.at("page-path", default: none)
  let canonical-url = if website-url != none and page-path != none {
    let clean-site-url = website-url.trim("/", at: end)
    let clean-path = page-path.trim("/")
    if clean-path == "" {
      clean-site-url + "/"
    } else {
      clean-site-url + "/" + clean-path + "/"
    }
  } else {
    none
  }

  if canonical-url != none {
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
