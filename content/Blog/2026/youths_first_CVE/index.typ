#import "../../../../config.typ": template, tufted
#import "@preview/theorion:0.6.0": *
#let post = (
  title: [年轻人的第一个 CVE],
  date: datetime(year: 2026, month: 10, day: 16),
  tag: ("Linux", "安全"),
  comments: true,
)
#show: template.with(..post)

#title()
其实我对安全并不感兴趣。年轻时误打误撞发现了漏洞#footnote[我当时还真不觉得算是漏洞]，还直接把它发到了论坛上，现在看真是烂活。虽然厂商马上盒了我，给了我美妙的封口费，然后把帖子拿掉了，厂商也加班加点修复了问题。但我是没有闲心去主动挖掘漏洞的。安全知识方面，我也只是在本科的时候，有那么几周围观了 CTF 社团，结果发现有限域上的代数纯坐牢，也就跑路了。

= 发现问题
所以，我不会去找漏洞，问题是漏洞会找上我。某一天，我发现 `krun` 是个好东西——能非常快地启动一个轻量级虚拟机，在大多数情况下，搭配上 `--annotation run.oci.handler=krun --annotation krun.use_passt=1` 这两个参数，就能无缝替代普通容器#footnote[其实情况更复杂，`krun` 自带一个叫做 TSI 的网络机制，本应该更透明，但是性能上有奇怪的问题，因此直到其支持 `passt` 网络之后我才真正考虑用上]。于是，我就寻思，这真的是太酷了——我要把所有面向公网的容器都换成这东西！

结果，bug 就迅速地找上了我，简而言之，要是用 root 启动容器，没有带上 `--userns auto`，容器就会光速报错，启动不起来：
#figure(
  ```bash
  $ sudo podman run -it --rm \
    --annotation krun.use_passt=1 \
    --annotation run.oci.handler=krun \
    --name test alpine:latest

  Error: OCI runtime error: crun: failed configuring mounts for handler at phase: HANDLER_CONFIGURE_AFTER_MOUNTS: start passt
  ```,
  caption: [这是一个简单的示例。用 root 启动容器，是因为真实负载需要端口转发；好孩子不要学，除非用 `userns` 限制容器权限]
)
问题不大，我加上 `--userns auto` 后，问题就消失了，但这让我感到莫名其妙，天底下只有权限不够报错的道理，哪有权限给多了报错的道理。不过好在现在是美妙的 agent 时代——我 `strace` 都懒得抓，开个 `codex`，提示词就是命令 A 报这个错，命令 B 没有报错，你去研究为啥。

过了一会儿，我都忘了这些事情，却在切终端窗口的时候发现 `codex` 的任务已经结束了，而且我忘记切模型了，干活的模型是 `deepseek`#footnote[有趣的是，我把相同的任务交给 `GPT-5.6-Sol`，结果当时这个闭源的 SOTA 模型闹了半天也没闹明白，说什么你这系统是 SELinux Enforcing，这些乱七八糟的报错肯定怪 SELinux 辣，没有 `strace` 这活我干不了]，但是问题不大，`deepseek` 已经完成了任务（我甚至忘记了给它 `podman, crun` 的代码路径，它都是手动从 GitHub 逐文件 fetch 下来的）。

`Deepseek` 给了非常详细的报告，原因很简单，没有 `userns` 的时候，因为有特权，`krun` 在容器的文件系统视图准备过程中，走了 `OPEN_TREE_NAMESPACE` 的快速路径#footnote[常见的做法是先 `unshare` 掉 `mntns`，然后构建好新的 `/`，这包括设置挂载点，然后 `pivot_root` 切过去，然后断开系统原有的 `/`。而 `OPEN_TREE_NAMESPACE` 快速路径是直接打开准备好的容器根，把它变成一棵独立的挂载树，原地切换进去，然后用之前握着的 `fd` 设置挂载点。所以 `HANDLER_CONFIGURE_AFTER_MOUNTS` 的时候，在默认路径下，容器的 `rootfs` 还只是一棵挂载好的子树，等待后续切换；但是 `OPEN_TREE_NAMESPACE` 之下，当前进程的根目录实际上已经切换了。]，而这个快速路径误将启动 `passt` 的时机放在了将 `/` 切换到容器根目录之后。而容器的文件系统中如果没有 `passt`——那么自然会失败。

我一看，这个报告合理得很，`deepseek` 甚至聪明地向我展示了如何构造一个容器，其中 `passt -> /bin/true`，然后 `podman` 就没意见了。我整理了一下，开了个 issue。考虑到现在是 agent 时代，顺手用 AI 修一手，混个 PR 也不错，于是把报告和代码丢给 GPT，让它帮我准备修复。

= 发现是安全问题

GPT 一看报告，炸了，告诉我，`passt` 的执行上下文刚刚切换到了容器的根目录，而用户还是 root，很多本应施加给容器的限制还没来得及用上，要是容器里面的 `passt` 实际上是个恶意进程，你不炸了？

我一看，说得也有道理，于是想要确认一下影响面，但是这时候 GPT 不乐意了：
#figure(
  html.img(src: "https://cdn.yanqiyu.info/2026/10/17/%E6%88%AA%E5%9B%BE%202026-10-01%2000-23-19.png"),
  caption:[我 GPT 见不得网络攻击，再见了您嘞]
)
没招了，切换回 `deepseek`，让它先给我准备一个 `passt` 约等于 `sleep +inf` 的镜像，我手动到 `/proc` 一看——果然，对应进程有完整的 root 权限，不过因为当前根目录已经切换到了容器的根目录，很多坏事似乎做不了，需要仔细地琢磨怎么借助这个权限逃逸出去。于是把任务交给了 `deepseek`，我开始给 #link("https://github.com/containers/crun")[`crun`] 写#link("https://github.com/containers/crun/security/advisories/GHSA-5f8q-v9f3-rhvj")[漏洞报告]。

不过写完之后，发现 `deepseek` 没琢磨出来逃逸路径#footnote[我给的任务是尝试读写根命名空间根目录中的文件，或者通过 `ptrace` 操作其进程等，以破坏容器隔离。]，看起来又是人工介入的时候了。我想起来，一般在容器启动阶段，为了方便之后创建挂载点之类的，`crun` 很可能在这个时候持有一些 host 端的 `fd`。于是我把这个想法告诉 AI，然后果不其然，它很快发现某个 `fd` 指向 host 的 `/proc`，然后顺着 `/proc/1/fd/<N>/1/root` 扫描 N，果然拿到了 host 的根目录，确认即使在 SELinux Enforcing 下，也能以 root 权限读写 host 上的任意文件。

= 各种小插曲
不过，整个过程充满了草台班子，即使在修复过程中，问题也层出不穷。
+ 首先是我提交的公开 issue：在漏洞报告提交数天之后，有个红帽子员工赶来——他也发现了问题的本质是快速路径先切根再启动 `passt`。但是他也没反应过来这是安全漏洞，想了个损招：先在 host 上打开 `passt` 的二进制，握着 `fd`，切换根之后通过 `fd` 启动 `passt`。而这显然是不灵的，因为启动 `passt` 的 `ld.so` 还是从容器的根目录加载的，还是会在错误的安全上下文中执行不可信代码。
+ 然后是最后的 advisory，其实红帽子的人灯下黑了一手，`krun.use_passt=1` 这个选项可以通过容器自带的一个配置文件开启，而不需要在命令行上指定。所以严格来说，最后的 advisory 中的叙述#quote-block[A malicious image can get code execution as root on the host, with read/write access to host files. Only rootful krun containers with krun.use_passt are affected.]并不完全成立——只要是 rootful 的 `krun`，就不能接触不可信镜像。
+ 最好笑的是，发布修复时，最初发布的 #link("https://github.com/containers/crun/releases/tag/1.30")[1.30 版本]漏掉了相应的修复；我问了一嘴之后，对方马上重新发布了#link("https://github.com/containers/crun/releases/tag/1.30.1")[1.30.1 版本]，这次才把修复合并上去。
