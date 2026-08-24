#let waline-comments(
  server-url: "https://waline.yanqiyu.info",
) = {
  let script = "(() => {
    const css = document.createElement('link');
    css.rel = 'stylesheet';
    css.href = 'https://cdn.jsdelivr.net/npm/@waline/client@v3/dist/waline.css';
    document.head.append(css);
    import('https://cdn.jsdelivr.net/npm/@waline/client@v3/dist/waline.js').then(({ init }) => {
      init({
        el: '#waline',
        serverURL: '" + server-url + "',
        path: window.location.pathname,
        meta: ['nick', 'mail', 'link'],
        requiredMeta: ['nick'],
        lang: 'zh-CN',
        emoji: [
          'https://cdn.jsdelivr.net/gh/walinejs/emojis@1.0.0/tw-emoji',
          'https://cdn.jsdelivr.net/gh/walinejs/emojis@1.0.0/bilibili',
        ],
        dark: 'html[data-theme=dark]',
        wordLimit: 4096,
        pageSize: 10,
        placeholder: '这是评论区',
        avatar: 'retro',
        highlight: true,
        avatarCDN: 'https://gravatar.loli.net/avatar/',
        avatarForce: false,
      });
    });
  })();"

  html.elem(
    "article",
    attrs: (id: "comments", class: "comments"),
    [
      #html.elem("div", attrs: (id: "waline"), "")
      #html.elem("script", attrs: (type: "module"), script)
      #html.elem("noscript", "Please enable JavaScript to view the comments")
    ],
  )
}
