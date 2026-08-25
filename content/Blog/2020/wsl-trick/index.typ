#import "../../../../config.typ": template, tufted
// 原文件: source/_posts/wsl-trick.md
// 原文时间: 2020-03-27 17:54:47
// tags: 瞎折腾, WSL
#let post = (
  title: [一些绝妙的 WSL 技巧],
  date: datetime(year: 2020, month: 3, day: 27),
  tag: ("瞎折腾", "WSL", "Linux"),
  comments: true,
)
#show: template.with(..post)

#title()

想起来了就更新一点:

= 统一 DBUS 会话
Linux 下有些程序会通过 dbus 来启动, 如果没有 dbus 的话就会出错或者花很长时间开个新的 dbus. 使用:

```bash
daemonize -e /tmp/dbus-${USER}.log -o /tmp/dbus-${USER}.log -p /tmp/dbus-${USER}.pid -l /tmp/dbus-${USER}.pid -a /usr/bin/dbus-daemon --address="unix:path=/tmp/dbus-${USER}" --session --nofork  >>/dev/null 2>&1
export DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/dbus-${USER}"
```

加到 `~/.bash_profile` 就可以在每次启动 wsl 实例时启动dbus, 然后让所有会话用这个 dbus 实例. `/tmp/dbus-${USER}` 可以相应的修改成你喜欢的路径

= 经过修改的 xdg-open
#link("https://github.com/cpbotha/xdg-open-wsl")[这里] 有魔改版的 `xdg-open`, 放到你的可执行文件路径里面, 就可以用 `xdg-open` 命令调用 Windows 下的程序进行操作了(例如 jupyter 打开浏览器以及 texdoc 打开帮助文档 pdf).
