---
title: 在 WSL 2 下运行 Anbox
date: 2020-03-27 12:53:49
index_img: /2020/03/27/anbox-in-wsl/1.webp
tags: 
- 瞎折腾
- WSL
categories: 技术
---

## 介绍

这本来是我之前在 reddit 上面发的一个[帖子](https://www.reddit.com/r/bashonubuntuonwindows/comments/eofn5s/run_anbox_on_wsl_2/). 现在干脆把它重新写成中文, 姑且算是给自己引流.

[Anbox](https://anbox.io/) 实现了基于 lxc 的 Android on Linux 支持, 由于 WSL 2 就是完整的 Linux, 于是稍加折腾就能跑起来了. 

## 安装 anbox

我在 [copr](https://copr.fedorainfracloud.org/coprs/yanqiyu/anbox/) 上有现成的 Anbox build, 直接安装即可. 我使用的 WSL 内发行版是 [Fedora Remix](https://github.com/WhitewaterFoundry/Fedora-Remix-for-WSL).

Ubuntu 上我也试过, **但是不能正常显示(窗口啥都没有)**, 但是 **Android 跑起来了**, 可能是 SDL 的锅. 跑 **Arch** 的 WSL 也能跑起来 **步骤几乎相同**.
    
    $ sudo dnf copr enable yanqiyu/anbox
    $ sudo dnf install anbox

## 从源代码编译

你需要 [anbox-modules](https://github.com/anbox/anbox-modules) 和 [kernel](https://github.com/microsoft/WSL2-Linux-Kernel/releases) 的源代码. 内核源代码选择和你的 WSL 一致的版本(`uname -r`).

我这儿是 `4.19.84-microsoft-standard`, 下面的步骤以此为例, 如果你的版本不一样, 直接换掉版本就成.

解压并准备好编译. (我把它解压到了 `~/WSL2-Linux-Kernel-4.19.84-microsoft-standard`).

    $ cd WSL2-Linux-Kernel-4.19.84-microsoft-standard
    $ cp /proc/config.gz ./
    $ gzip -d config.gz
    $ mv config .config
    $ sudo dnf install bison flex elfutils-libelf-devel openssl-devel -y
    $ make prepare
    $ make modules_prepare
    $ sudo mkdir -p /lib/modules/4.19.84-microsoft-standard
    $ sudo ln /home/(USERNAME)/WSL2-Linux-Kernel-4.19.84-microsoft-standard -s /lib/modules/4.19.84-microsoft-standard/build

编译模块

    $ git clone https://github.com/anbox/anbox-modules.git
    $ sudo cp -rT ashmem /usr/src/anbox-ashmem-1
    $ sudo cp -rT binder /usr/src/anbox-binder-1
    $ sudo dkms install anbox-ashmem/1
    $ sudo dkms install anbox-binder/1

安装模块

    $ sudo modprobe ashmem_linux
    $ sudo modprobe binder_linux

可能会有报错, 完全正常, 只要下面的命令输出提示模块正常工作就行

    $ lsmod | grep -e ashmem_linux -e binder_linux
    $ ls -alh /dev/binder /dev/ashmem

## 安装 Android 镜像

在 [这里](https://build.anbox.io/android-images) 下载 Android 镜像

放到 `/var/lib/anbox/android.img`

## 启动 anbox!

### 提前准备

    $ export $(dbus-launch)
    $ mkdir /tmp/runtime-user
    $ export XDG_RUNTIME_DIR=/tmp/runtime-user

### 运行!

    $ anbox-bridge.sh start
    $ sudo daemonize /usr/bin/anbox container-manager --daemon --privileged --data-path=/var/lib/anbox
    $ anbox launch --package=org.anbox.appmgr --component=org.anbox.appmgr.AppViewActivity

## 修复网络

使用 `anbox/scripts/anbox-shell.sh` 的脚本获得 Anbox 中的管理员权限

    ip route add default dev eth0 via 192.168.250.1
    ip rule add pref 32766 table main
    ip rule add pref 32767 table local

## 效果

![运行截图](1.webp)


## 当前问题

* 试图打开设置首页铁定会崩溃, 可能和[这个](https://github.com/anbox/anbox-modules/issues/41)有关
* Ubuntu 下不好使, 虽然可能和 SDL 之类的有关, 但是我也不想管
* 没图形加速