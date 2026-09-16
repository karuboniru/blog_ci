/// Plain metadata text, separate from the rich content rendered in the body.
/// Traverse semantic content fields, never Typst source or rendered HTML.
#let plain-text(value) = {
  if value == none { return "" }
  if type(value) == str { return value }
  if type(value) == array { return value.map(plain-text).join(default: "") }
  if type(value) != content { return "" }
  if value.func() == [ ].func() { return " " }
  if value.func() == linebreak or value.func() == parbreak { return "\n" }
  if value.func() == smartquote { return if value.double { "\"" } else { "'" } }
  if value.has("text") { return value.text }
  value.fields().values().filter(v => type(v) in (content, array)).map(plain-text).join(default: "")
}
