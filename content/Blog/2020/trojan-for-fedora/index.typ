#import "../../../../config.typ": template, tufted
// 原文件: source/_posts/trojan-for-fedora.md
// 原文时间: 2020-06-21 09:12:50
// tags: 打包
#let post = (
  title: [Trojan for Fedora and EPEL],
  date: datetime(year: 2020, month: 6, day: 21),
  tag: ("打包",),
  comments: true,
)
#show: template.with(..post)

#title()

#link("https://github.com/trojan-gfw/trojan/")[Trojan] 即将在 Fedora 操作系统官方源(含 EPEL 8)可用🎉.

详情可见 #link("https://bodhi.fedoraproject.org/updates/?search=trojan")[Fedora Bodhi], 以及 #link("https://github.com/trojan-gfw/trojan/issues/462")[Trojan issue \#462].

在 Trojan 进入 stable 仓库之后我会去更新一下 Trojan 那边的安装教程, 顺便在这里也写一下. 等到软件进入 Testing 之后大家也可以帮忙测试. 有这个版本特有的问题（来自于打包等的问题）请汇报#link("https://bugzilla.redhat.com/buglist.cgi?bug_status=NEW&bug_status=ASSIGNED&classification=Fedora&component=trojan&product=Fedora&product=Fedora%20EPEL")[Bugzilla]或者是#link("mailto:yanqiyu@fedoraproject.org")[邮件联系我]. 来自于上游的问题可以#link("https://github.com/trojan-gfw/trojan/issues")[直接汇报给上游], 但请注明软件包安装来源.

= Update 20/6/22
已经可用

```
Package: trojan-1.16.0-4.fc33
Summary: An unidentifiable mechanism that helps you avoid censorship
RPMs:    trojan
Size:    1.54 MiB
```

= 接下来是 clash
Clash 已经在 fedora 官方源可用!
