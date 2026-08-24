#import "../index.typ": template, tufted
#show: template.with(
  title: "Blog",
  description: "Karuboniru 的博客归档",
)

= 博客 / Blog

== 2025
#tufted.blog-entry(
  date: datetime(year: 2025, month: 4, day: 20),
  path: "/2025/04/20/macsec_in_vxlan/",
  title: "一种很怪的隧道 (MACsec in VXLAN)",
)
#tufted.blog-entry(
  date: datetime(year: 2025, month: 2, day: 19),
  path: "/2025/02/19/build_your_own_ostree_system/",
  title: "Build your own fedora OSTree Remix",
)

== 2023
#tufted.blog-entry(
  date: datetime(year: 2023, month: 11, day: 12),
  path: "/2023/11/12/singleton/",
  title: "Singleton Patterns are DANGEROUS (when used across the border of shared libraries)",
)
#tufted.blog-entry(
  date: datetime(year: 2023, month: 3, day: 9),
  path: "/2023/03/09/laptop/",
  title: "整点新笔记本",
)

== 2022
#tufted.blog-entry(
  date: datetime(year: 2022, month: 8, day: 10),
  path: "/2022/08/10/btrfs-ENOSPC/",
  title: "Don't Panic",
)

== 2021
#tufted.blog-entry(
  date: datetime(year: 2021, month: 12, day: 1),
  path: "/2021/12/01/build_fedora_iot_router/",
  title: "Building a router based on Fedora IoT",
)
#tufted.blog-entry(
  date: datetime(year: 2021, month: 10, day: 25),
  path: "/2021/10/25/waydroid-fedora/",
  title: "Waydroid on Fedora",
)
#tufted.blog-entry(
  date: datetime(year: 2021, month: 6, day: 29),
  path: "/2021/06/29/wslg-gpu/",
  title: "尝试 WSLg 以及启用图形加速",
)
#tufted.blog-entry(
  date: datetime(year: 2021, month: 6, day: 21),
  path: "/2021/06/21/huawei-v-qwr/",
  title: "某不知名网友怒斥华为，究竟发生了什么",
)
#tufted.blog-entry(
  date: datetime(year: 2021, month: 5, day: 6),
  path: "/2021/05/06/hands-on-coreos/",
  title: "上手 Fedora CoreOS，以搭建代理为例",
)
#tufted.blog-entry(
  date: datetime(year: 2021, month: 4, day: 30),
  path: "/2021/04/30/systemd-boot-and-unified-kernel-image/",
  title: "Switch to systemd-boot and Unified Kernel Image on Fedora",
)
#tufted.blog-entry(
  date: datetime(year: 2021, month: 3, day: 15),
  path: "/2021/03/15/yolo-fedora34/",
  title: "莽一把，升级 Fedora 34",
)
#tufted.blog-entry(
  date: datetime(year: 2021, month: 3, day: 6),
  path: "/2021/03/06/cloudflare-pages/",
  title: "我是来吹 Cloudflare Pages 的",
)

== 2020
#tufted.blog-entry(
  date: datetime(year: 2020, month: 11, day: 6),
  path: "/2020/11/06/fcitx5-fedora-updated/",
  title: "如何更加优雅的在 fedora 上安装 fcitx5",
)
#tufted.blog-entry(
  date: datetime(year: 2020, month: 9, day: 26),
  path: "/2020/09/26/geant4-basic/",
  title: "轻松的安装 Geant4",
)
#tufted.blog-entry(
  date: datetime(year: 2020, month: 8, day: 30),
  path: "/2020/08/30/fcitx5-fedora/",
  title: "如何下周就在 Fedora 32 用上 Fcitx 5",
)
#tufted.blog-entry(
  date: datetime(year: 2020, month: 8, day: 22),
  path: "/2020/08/22/enhanced-hyperv-for-fedora/",
  title: "在 Hyper-V 会话中对于 Fedora 启用增强会话",
)
#tufted.blog-entry(
  date: datetime(year: 2020, month: 6, day: 21),
  path: "/2020/06/21/trojan-for-fedora/",
  title: "Trojan for Fedora and EPEL",
)
#tufted.blog-entry(
  date: datetime(year: 2020, month: 5, day: 13),
  path: "/2020/05/13/Geant4-one-pitfall/",
  title: "Geant 4 的一个坑",
)
#tufted.blog-entry(
  date: datetime(year: 2020, month: 3, day: 30),
  path: "/2020/03/30/Noetherstheorem/",
  title: "诺特定律",
)
#tufted.blog-entry(
  date: datetime(year: 2020, month: 3, day: 30),
  path: "/2020/03/30/building/",
  title: "博客创建过程与总结",
)
#tufted.blog-entry(
  date: datetime(year: 2020, month: 3, day: 27),
  path: "/2020/03/27/anbox-in-wsl/",
  title: "在 WSL 2 下运行 Anbox",
)
#tufted.blog-entry(
  date: datetime(year: 2020, month: 3, day: 27),
  path: "/2020/03/27/plan/",
  title: "规划",
)
#tufted.blog-entry(
  date: datetime(year: 2020, month: 3, day: 27),
  path: "/2020/03/27/wsl-trick/",
  title: "一些绝妙的 WSL 技巧",
)
