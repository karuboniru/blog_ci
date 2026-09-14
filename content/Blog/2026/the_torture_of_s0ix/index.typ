#import "../../../../config.typ": template, tufted
#import "@preview/theorion:0.6.0": *
#let post = (
  title: [一场名为 S0ix 的折磨],
  date: datetime(year: 2026, month: 9, day: 14),
  tag: ("记录","Linux"),
  comments: true,
)
#show: template.with(..post)

#title()

= 发现深埋已久的 S0ix 问题

其实我自打一开始就觉得笔记本待机时似乎有点微妙的耗电和发热，但关于这一点我从来没有细想过。直到前段时间强行升级了 Fedora 45 预发行版#footnote[
  我倾向于在 rawhide branch 发布之后的几天内升级，具体几天取决于我的心情。敢于这么折腾的原因是#link("/Blog/2025/build_your_own_ostree_system/")[使用自己的 Ostree 分发]让我随时都有后悔药可吃。
]。然后发现新的 GNOME 会随机出现显示卡顿，于是本着灵车就要配灵车的鬼点子，我就把显卡驱动切换成了 `xe`。而切换之后，我让 AI 帮我检查一下 `xe` 是否正确驱动了我的显卡，结果 AI 一通折腾——发现笔记本在待机之后没有进入 S0ix 状态。然后我惊奇地发现，就算把显卡驱动切换回 `i915`，笔记本也依旧无法进入 S0ix 状态——原来我的笔记本的 S0ix 一直是坏的。

= 第一轮 —— 硬件问题
硬件问题反倒是好排查的，我把遇到的问题告诉神奇的 ChatGPT 5.6-Sol 之后，它给出了很多有价值的排查方向#footnote[
  也有很多没价值的，比如其一直在琢磨 xHCI 设备的问题，而我都看得出来，在进入 PC10 状态后整个 xHCI 控制器都进入省电状态了，你在意设备的支持干啥...
]。最有用的一条是检查 PCIe 设备的 ASPM 支持：
#figure(
  { 
    ```
    2e:00.0 Non-Volatile memory controller: MAXIO Technology (Hangzhou) Ltd. NVMe SSD Controller MAP1202 (DRAM-less) (rev 01) (prog-if 02 [NVM Express])
      LnkCap: Port #0, Speed 8GT/s, Width x4, ASPM not supported 
        ClockPM+ Surprise- LLActRep- BwNot- ASPMOptComp+ 
      LnkCtl: ASPM Disabled; RCB 64 bytes, LnkDisable- CommClk+ 
      L1SubCap: PCI-PM_L1.2+ PCI-PM_L1.1+ ASPM_L1.2- ASPM_L1.1- L1_PM_Substates+ 
      L1SubCtl1: PCI-PM_L1.2+ PCI-PM_L1.1+ ASPM_L1.2- ASPM_L1.1- 
      L1SubCtl2: T_PwrOn=44us
    ```
  },
  caption: {`sudo lspci -vv | grep -E '^[0-9a-f]{2}:[0-9a-f]{2}\.|ASPM|LnkCtl:|L1Sub'`}
)
哦，似乎我自己给笔记本加的那块梵想的 NVMe SSD 不支持 ASPM，看起来这是一个硬性的 blocker。

== `S0ixSelftestTool` 带领我走的弯路
AI 的鬼点子是，虽然我们已经发现了罪魁祸首，但是万一呢，不如先跑一下#link("https://github.com/intel/S0ixSelftestTool")[专业的测试工具]，看看它怎么说。结果是其中的弯弯绕复杂得令人头疼，这个工具总会怪罪某条 PCIe 链路没有进入低功耗状态 —— 而被怪罪的链路归属于另外一条 SSD。进入罗生门环节之后又是好几轮排查，我最终怀疑是有设备整个没能进入低功耗状态，于是虚拟的逻辑链路报告的状态就卡在了某个环节——总而言之，在设置了
```
echo powersupersave | sudo tee /sys/module/pcie_aspm/parameters/policy
```
之后，再跑一轮测试，AI 的口径终于变成了
#quote-block[
  这次结果几乎把问题钉死到 `00:1d.0 → 2e:00.0 MAP1202/Fanxiang S500PRO` 这一条 PCIe 链了。
]

于是我也就修改了一下挂载点，先把那块 SSD 拔掉了；因为一半的 home 在上面，我改用 root 登录 console 测试了一下，果然，S0ix 终于可以进入了。于是我就把问题归结为硬件问题——从抽屉里面又找了一个容量类似的硬盘，换上去，迁移数据，发现 ASPM 正确启用，S0ix 也正常。问题似乎就解决了。

= 可是，果然如此吗？
好笑的事情出现了，等我哼哧哼哧挪动完数据，重新进入桌面，再次运行休眠测试。结果——S0ix 依旧无法进入，还有第二关。然后就是更加复杂的 A/B 测试：
+ 开机之后在终端登录任意账号——休眠正常
+ 进入桌面之后——休眠不正常
+ `loginctl kill-user` 干掉所有桌面程序之后——休眠不正常

见鬼的环节就是，似乎进入桌面这个行为在系统里遗留下了某种隐藏的状态变化。而 AI 到了这一步就开始抓瞎，建议我抓取从 `/sys` 到 PCIe configuration space 的、数以亿计的结果，然而却又没能给出任何有价值的结论。

于是我就回到传统手艺：先创建一个新的用户，登录桌面，发现 S0ix 恢复——问题和我桌面环境的配置有关。然后我就开始一条一条地禁用桌面环境的扩展，发现问题出在某个用 `ddcutil` 控制外接显示器的扩展上。禁用这个扩展之后，S0ix 终于恢复正常。

虽然问题的根因依旧不清楚，但我猜是它在 `i2c` 上 probe 显示器的时候，某些 probe 行为修改了某个设备的状态，从而破坏了脆弱的 S0ix 进入条件。
