---
title: 一些绝妙的 WSL 技巧
date: 2020-03-27 17:54:47
tags: 
- 瞎折腾
- WSL
categories: 技术
---

想起来了就更新一点:

## 统一 DBUS 会话

Linux 下有些程序会通过 dbus 来启动, 如果没有 dbus 的话就会出错或者花很长时间开个新的 dbus. 使用:

    if [ -z "$(pidof dbus-daemon)" ]; then
        /usr/bin/dbus-launch --exit-with-x11 2>/dev/null  >~/.dbus.env
    fi
    export $(cat ~/.dbus.env)
加到 `~/.bash_profile` 就可以在每次启动 wsl 实例时启动dbus, 然后让所有会话用这个 dbus 实例.

## 经过修改的 xdg-open

[这里](https://github.com/cpbotha/xdg-open-wsl)有魔改版的 `xdg-open`, 放到你的可执行文件路径里面, 就可以用 `xdg-open` 命令调用 Windows 下的程序进行操作了(例如 jupyter 打开浏览器以及 texdoc 打开帮助文档 pdf).
