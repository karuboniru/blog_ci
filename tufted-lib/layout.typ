// TODO: figures and figures with captions inside margin notes

#let has-margin-note(node) = {
  if node.func() == html.elem and node.has("attrs") and (
    node.attrs.at("class", default: "").split().contains("marginnote")
  ) {
    return true
  }
  if node.has("children") {
    return node.children.any(has-margin-note)
  }
  if node.has("body") and type(node.body) == content {
    return has-margin-note(node.body)
  }
  false
}

#let margin-note(content) = {
  html.elem(
    "span",
    attrs: (
      class: "sidenote-anchor",
      aria-hidden: "true",
    ),
    "\u{2060}",
  )
  box(html.div(class: "marginnote sidenote-manual", role: "note", content))
}

// TODO: implement <figure class="fullwidth">
// possible requires introspection or `set html.figure(class: "fullwidth")` support

#let full-width(content) = {
  html.div(class: "fullwidth", content)
}
