#import "../../config.typ": template, tufted
#import "../../tufted-lib/tags.typ": tag-id
#import "../Blog/_posts.typ": post-sources

#let tag-css = "
.tag-group {
  width: 55%;
  border-bottom: 1px solid var(--theme-table-border, #ccc);
  scroll-margin-top: 1em;
}

.tag-group summary {
  cursor: pointer;
  padding: 1em 0;
  font-size: 1.5em;
}

.tag-group .blog-entry {
  width: 100%;
}

.tag-group:target > details > summary {
  color: var(--theme-link, inherit);
  background: var(--highlight-weak);
  border-radius: var(--radius-sm);
}

@media (max-width: 760px) {
  .tag-group {
    width: 100%;
  }
}
"

#let tag-script = "(() => {
  const revealTargetTag = () => {
    const id = window.location.hash.slice(1);
    if (!id) return;

    const group = document.getElementById(id);
    if (!group?.classList.contains('tag-group')) return;

    const details = group.querySelector(':scope > details');
    if (!details) return;

    details.open = true;
    requestAnimationFrame(() => group.scrollIntoView({ block: 'start' }));
  };

  window.addEventListener('hashchange', revealTargetTag);
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', revealTargetTag, { once: true });
  } else {
    revealTargetTag();
  }
})();"

#show: template.with(
  title: [标签 / Tags],
  description: [Karuboniru 的博客标签归档],
  head-elements: (
    html.elem("style", tag-css),
    html.elem("script", tag-script),
  ),
)

#title()

#let posts = post-sources.map(source => {
  let article-source = "../Blog/" + source.source
  import article-source as article
  article.post + (path: "/Blog/" + source.path,)
})

#let post-tags(post) = {
  let tag = post.at("tag", default: ())
  if type(tag) == str { (tag,) } else { tag }
}

#let tags = posts.fold(
  (),
  (tags, post) => tags + post-tags(post),
).dedup().sorted()

#for tag in tags {
  let tagged-posts = posts.filter(
    post => post-tags(post).contains(tag),
  ).sorted(key: post => post.date).rev()

  html.div(
    id: tag-id(tag),
    class: "tag-group",
    html.details(
      name: "tags",
      open: false,
      {
        html.summary(tag + " (" + str(tagged-posts.len()) + ")")
        for post in tagged-posts {
          tufted.blog-entry(
            date: post.date,
            path: post.path,
            title: post.title,
          )
        }
      },
    ),
  )
}
