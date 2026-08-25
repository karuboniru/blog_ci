/// Return a stable, URL-safe HTML id for a tag name.
#let tag-id(name) = {
  let codepoints = name.normalize().codepoints()
  "tag-" + codepoints.map(
    char => str(char.to-unicode(), base: 16),
  ).join("-")
}
