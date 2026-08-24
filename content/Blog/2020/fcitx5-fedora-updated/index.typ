#import "../../../index.typ": template, tufted
// 原文件: source/_posts/fcitx5-fedora-updated.md
// 原文时间: 2020-11-06 16:41:10
// 更新时间: 2020-11-06 16:41:10
// categories: 打包
#show: template.with(
  title: "如何更加优雅的在 fedora 上安装 fcitx5",
  date: datetime(year: 2020, month: 11, day: 6),
  extra-info: "分类：打包",
  comments: true,
)

= 如何更加优雅的在 fedora 上安装 fcitx5

感谢囧脸的努力，fcitx5 也进入了正式 release 的阶段。当然，Fedora 官方源里面的 fcitx5 也即将切换到 release 版本。相对于之前的版本，有些信息需要相应的更新，于是有了这篇文章。

新版本的 fcitx5 及其组件在现在（写文章时）还在 test 仓库，想要安装的可以从中安装尝试，升级方法见 #link("https://bodhi.fedoraproject.org/updates/FEDORA-2020-127a30ec63")[bodhi]。

=== 对应升级用户，变更如下：
- 如果你是使用 imsettings 设置输入法或者是通过 alternatives 设置输入法的，那么你不会感知到变化。
- 如果你是通过符号链接 `ln -s /usr/share/applications/fcitx5.desktop ~/.config/autostart/` 设置输入法的，那么自动启动会挂掉，你需要删除原来的符号链接并 `ln -s /usr/share/applications/org.fcitx.Fcitx5.desktop ~/.config/autostart/` 重新创建
- 如果你是 `cp /usr/share/applications/fcitx5.desktop ~/.config/autostart/` 设置的自动启动的话，你应该不会感知到变化，但是我建议你删除旧的文件重新拷贝一个新的。
- 无论如何，你都可以放弃原来的自动启动和环境变量，安装 fcitx5-autostart 软件包

=== 对应新安装的用户
直接安装 `fcitx5`、`fcitx5-chinese-addons`、`fcitx5-gtk`、`fcitx5-qt`以及`fcitx5-configtool` 就能完成输入法的安装。安装 `fcitx5-autostart` 就能解决自启动。

如果你只希望 per user 的配置而非类似于 fcitx5-autostart 那样针对所有用户，那么可以参见 #link("/Blog/2020/fcitx5-fedora/")[前文]，不过相应的把 `/usr/share/applications/fcitx5.desktop` 换成 `/usr/share/applications/org.fcitx.Fcitx5.desktop` 即可。
