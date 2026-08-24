#import "../../../../index.typ": template, tufted
// 原文件: source/_posts/wslg-gpu.md
// 原文时间: 2021-06-29 13:31:03
// tags: 瞎折腾
// categories: 瞎折腾
#show: template.with(
  title: "尝试 WSLg 以及启用图形加速",
  date: datetime(year: 2021, month: 6, day: 29),
  extra-info: "标签：瞎折腾 | 分类：瞎折腾",
  comments: true,
)

= 尝试 WSLg 以及启用图形加速

== 关于 WSLg
在老早之前微软就宣布了 #link("https://devblogs.microsoft.com/commandline/the-initial-preview-of-gui-app-support-is-now-available-for-the-windows-subsystem-for-linux-2/")[WSL 支持图形界面]，这个项目的代号就叫做 WSLg。因为不常用 Windows 于是我其实一直没有尝试这东西，直到昨天 Windows 11 推送 insider 版本。我为了尝试 Windows 11 找了个电脑升级之后，#strike[发现最想要的 Android 模拟器还没加进来，]感叹微软虚假宣传之外，顺便尝试下 WSLg 的玩法。

#strike[其实最令人感到奇妙的就是 WSLg 都用上了 Wayland，然而有些发行版的 Wayland 支持还是不积极。]

== 使用 WSLg
在很多地方已经有了详细的介绍，开启 WSLg 首先就要开启 WSL2，首先要去 `启用或关闭 Windows 功能` 里面开启 `适用于 Linux 的 Windows 子系统` 以及 `虚拟机平台`，注意后者有很多名字类似的，不要开错了。然后安装 WSL 的发行版。我还是老样子选了 #link("https://github.com/WhitewaterFoundry/Fedora-Remix-for-WSL")[修改版的 Fedora]。因此后面的绝大多数内容都是针对 Fedora 的。

== 体验
#html.img(src: "https://cdn.yanqiyu.info/20210701201430.jpg") #html.img(src: "https://cdn.yanqiyu.info/20210701201429.jpg") #html.img(src: "https://cdn.yanqiyu.info/20210701201422.jpg")

基本达到了作为一个桌面可用的阶段，但是坑依旧很多，并且坑是各方位的…

== DBus
DBus 作为现在 Linux 桌面关键的组建（我觉得）本应在 WSLg 里面配置，可惜微软没有做，需要我们自己折腾：

=== Session Bus
Session Bus 用于用户自己的程序之间相互沟通，比如多数输入法或者 `Gnome-Terminal` 都需要 Session Bus 才能正确工作。首先安装需要的软件包

- `daemonize`
- `dbus-daemon`

然后在你的 `~/.bash_profile` (或者随便哪个你觉得合适的地方) 加上

```bash
daemonize -e /tmp/dbus-${USER}.log -o /tmp/dbus-${USER}.log -p /tmp/dbus-${USER}.pid -l /tmp/dbus-${USER}.pid -a /usr/bin/dbus-daemon --address="unix:path=$XDG_RUNTIME_DIR/bus" --session --nofork  >>/dev/null 2>&1
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
```

原理很简单，就是 `/tmp/dbus-${USER}.pid` 作为 lockfile 保证 dbus 是单实例的，监听地址就在 `unix:path=$XDG_RUNTIME_DIR/bus`，也就是 XDG 规定的默认地址。并设置环境变量。

=== System Bus
System Bus 用到的情况就要少一点了，但是为了整活运行 `gnome-control-center` 需要可用的 System Bus。并且因为权限的问题，最好借助 WSL 自己的 boot 功能实现。

首先准备一个脚本，我放到了 `/usr/local/bin/boot.sh`，内容是

```bash
#!/bin/bash

/usr/bin/mkdir -p /run/dbus/
/usr/bin/dbus-daemon --system
```

然后在 `/etc/wsl.conf` 中添加以下字段

```ini
[boot]
command=/usr/local/bin/boot.sh
```

这里又有个坑，就是前面脚本必须写完路径，因为这个脚本执行的时候还没有 `PATH` 环境变量。

== 输入法
对于输入法的配置就相对简单了（虽然还是有坑），#link("/2020/11/06/")[首先在 WSL 里面安装 fcitx5 相关软件包]，然后启动 fcitx5 进行测试… 发现 fcitx5 默默退出。仔细研究之后发现问题在 wayland 插件上面，于是应该加上 `--disable=wayland` 才好使。因此，最终在 `~/.bash_profile` (或者随便哪个你觉得合适的地方) 加上：

```bash
daemonize -e /tmp/fcitx5.log -o /tmp/fcitx5.log -p /tmp/fcitx5.pid -l /tmp/fcitx5.pid -a /usr/bin/fcitx5 --disable=wayland
export INPUT_METHOD=fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
```

== GPU 加速
虽然背后的故事很复杂，但是为了实现图形加速，你需要

- 开启了 `d3d12` 选项的 mesa `> 21`
- 支持 WDDM 3.0 的驱动

Windows 侧需要的驱动可以在

- #link("https://community.amd.com/community/radeon-pro-graphics/blog/2020/06/17/announcing-amd-support-for-gpu-accelerated-machine-learning-training-on-windows-10")[AMD GPU driver for WSL]
- #link("https://downloadcenter.intel.com/download/29526")[Intel GPU driver for WSL]
- #link("https://developer.nvidia.com/cuda/wsl")[NVIDIA GPU driver for WSL]

下载，安装后。就是捣鼓 mesa 了。首先把 `exclude=mesa*` 添加到 `/etc/yum.repos.d/{fedora.repo, fedora-updates.repo, fedora-updates-testing.repo}` 的第一个块里面，禁用掉系统源的 mesa，然后

```bash
sudo dnf swap generic-release fedora-release
sudo dnf copr enable yanqiyu/mesa
sudo dnf reinstall mesa*
sudo dnf install mesa-d3d12
```

然后图形加速应该就可用了。可以用 `glxinfo -B` 检验下。
