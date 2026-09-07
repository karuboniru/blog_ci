#import "layout.typ": has-margin-note

#let template-notes(content) = {
  // Keep notes in the text flow without nesting block content inside a <p>.
  show par: it => if target() == "html" and has-margin-note(it.body) {
    html.div(class: "sidenote-paragraph", it.body)
  } else {
    it
  }

  show footnote: it => {
    if target() == "html" {
      let number = counter(footnote).display(it.numbering)
      let fn-id = "fn-" + number
      let ref-id = "fnref-" + number

      // Numeric references in the main text
      html.sup(class: "footnote-ref", html.a(
        class: "footnote-ref-link",
        href: "#" + fn-id,
        id: ref-id,
        number,
      ))

      // Footnote content in the margin
      box(html.div(
        class: "marginnote sidenote-footnote",
        id: fn-id,
        role: "note",
        html.div(
          class: "sidenote-note-layout",
          html.span(
            class: "sidenote-label",
            html.sup(html.a(class: "footnote-ref-link", href: "#" + ref-id, number)),
          ) + box(html.div(class: "sidenote-body", it.body)),
        ),
      ))
    }
  }
  content
}
