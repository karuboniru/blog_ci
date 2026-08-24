#import "../../../../index.typ": template, tufted
// 原文件: source/_posts/fcitx5-fedora.md
// 原文时间: 2020-08-30 17:44:07
// 更新时间: 2020-11-06 16:41:10
// categories: 打包
#show: template.with(
  title: "如何下周就在 Fedora 32 用上 Fcitx 5",
  date: datetime(year: 2020, month: 8, day: 30),
  extra-info: "分类：打包",
  comments: true,
)

= 如何下周就在 Fedora 32 用上 Fcitx 5

本文内容已经严重过时，请参阅 #link("/2020/11/06/")[这篇更新的文章] 设置你的 fcitx5

#html.hr()

一开始想了想要不要在标题写 Fedora，觉得还是必要的。因为目前只有 Arch Linux （和 Debian 和 Ubuntu）出于套近乎的关系有了 Fcitx 5 全家桶。

为什么是下周？------因为 Fedora 的 QA，#strong[包最长会在 #link("https://bodhi.fedoraproject.org/updates/FEDORA-2020-5465c02630")[Bodhi] 等一周，除非你们帮忙测试，点个 upvote] (๑•̀ㅂ•́)و✧。

测试大概明天或者后天上线，想要参与就`dnf install --enablerepo=updates-testing`来进行安装。

#html.hr()

== 建议安装的包
- fcitx5 \
- fcitx5-gtk
- fcitx5-qt
- fcitx5-configtool \
- fcitx5-chinese-addons

另外之前用了我的 #link("https://copr.fedorainfracloud.org/coprs/yanqiyu/fcitx5")[copr] 版本的人，请保证把里面的包卸载之后在进行安装，否则可能出现奇妙的冲突。

虽然在别的发行版上面最新的 Fcitx 4/5 不能共存，但是在 Fedora 上能，rpm 能优雅的处理表面上的文件冲突。 对于原因感兴趣的可见#link("https://t.me/fedorazh/63996")[群里面的讨论]的上下文。

== 环境变量和自启动
=== 对于 KDE 用户
```bash
$ sudo alternatives --config xinputrc
```

即可修改全局输入法配置。但是想要修改自己的输入法配置可以考虑 im-settings 或者下面的方法。

=== 通用办法
写一个

```
INPUT_METHOD=fcitx5
GTK_IM_MODULE=fcitx5
QT_IM_MODULE=fcitx5
XMODIFIERS=@im=fcitx5
```

放到 `~/.config/environment.d/00-fcitx5.conf`

然后运行（当然 `ln -s` 可以换成 `cp`）

```bash
$ ln -s /usr/share/applications/fcitx5.desktop ~/.config/autostart/
```

同样#strong[注销之后重新登陆]就会生效。

别的情况可以酌情尝试上述两种办法，应该至少有一种会生效。

== 一些其他的提示
=== 对于 Gnome 用户
见 #link("https://plumz.me/archives/11740/")[李先生的博客] 文章，建议安装 #strong[kimpanel] 插件以改善体验。(以下引用 block 是直接厚颜无耻照抄的, 意味着内容可能过时，没准 Gnome 商店的版本也超级好使呢？)

#quote(block: true)[
众所周知，网络上吹 Fcitx 5 的用户大多数都是 Arch Linux 用户、而且用的都是 KDE，没有人告诉你 Gnome-shell 要怎么办，不过万幸的是伟大的囧脸的 Gnome shell 插件是支持 Fcitx 5 的，因为用的都是 Kimpanel，也就是说，装了这个 Gnome-shell extension，无论你是 Fcitx 4 还是 Fcitx 5，都是可以用的，赞美囧脸！ 不过这个插件在 Gnome 官方的 Extension 网站上的版本有一些问题：

- #link("https://github.com/wengxt/gnome-shell-extension-kimpanel/issues/46")[快速打字的时候会出现部分内容显示不全]
- 多显示器的时候会跨越显示器出现选字框
- #link("https://github.com/wengxt/gnome-shell-extension-kimpanel/issues/47")[锁屏后解锁会出现两个 Indicator]

不过这三个问题都已经被囧脸修复了，赞美囧脸！

安装的话还是推荐安装 git 的版本，因为官方的还没有更新：

```
https://github.com/wengxt/gnome-shell-extension-kimpanel
```

安装依赖：gettext cmake 后直接在目录下运行 ./install.sh 就可以了，记得把原本的插件删掉再装。
]

=== 图形界面配置工具
`fcitx5-configtool` 含有 `fcitx5-config-qt`，安装之后`fcitx5-config`就会调用之。另外还支持KCM配置，当然是KDE用户专享了。

== Bug Report
遇到问题，建议先在#link("https://bugzilla.redhat.com/buglist.cgi?bug_status=NEW&bug_status=ASSIGNED&classification=Fedora&component=fcitx5&list_id=11319828&product=Fedora&product=Fedora%20EPEL")[Bugzilla]反馈，如果是我的锅（打包翻车），我就修。如果是囧脸的锅，那我就找囧脸修。

当然要是你能判断是囧脸的锅，建议直接去上游找囧脸修。

== TODO List
- \[x\]，把 `kcm-fcitx5` 拆出来: #strong[已经在 rawhide 中完成，F32 再等等就 push]
- ☐ fcitx5-chinese-addons 拆包
- ☐ #strike[Fedora 31 上的编译], 不会有了, 因为貌似 fmt 版本太老, 编译不过, 这个包 F31 Mass Rebuild 之后居然就没更新过. 虽然我可以 Bundle 一个 header-only 的 fmt.

#emph[为什么现在不做，这些事情不复杂啊？] ------懒，但是要是你确实需要，#link("mailto:yanqiyu@fedoraproject.org")[给我说一声]，我尽快😂

== 此处应该感谢#link("https://www.csslayer.info/")[囧脸]
CSSlayer（囧脸）对于打包做出了巨大贡献，包括但不限于：

- 舍去刷蹦蹦蹦的时间深夜来修 aarch64 上的 bug
- 帮我识别出一个 s390x 上的错误的真正原因，还给 KenLM 提了 PR，修复了十有八九不会有活人遇到的 s390x 上的一个可能导致整个 chinese-addons 不好使的 bug

#html.hr()

最后高呼三遍：#strong[赞美囧脸！赞美囧脸！赞美囧脸！]
