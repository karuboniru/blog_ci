#import "../../../../config.typ": template, tufted
// 原文件: source/_posts/laptop.md
// 原文时间: 2023-03-09 12:51:03
// tags: 败家
#let post = (
  title: [整点新笔记本],
  date: datetime(year: 2023, month: 3, day: 9),
  tag: ("败家", "Linux"),
  comments: true,
)
#show: template.with(..post)

#title()

= 好端端的为啥要买电脑
自古以来，我的setup就是两台笔记本，一个游戏本…用来打游戏，另一个轻薄本，用来拿着到处跑还有写写代码。然后又有些历史背景，简单的说就是家里人不怎么会用电脑，也不愿意学。这一切形成的稳态直到我爸他们学校引入高大上的电教系统之后被打破了------我爸也要用电脑。

这事情本来很好办，用电脑嘛，老年人安排个红米笔记本，就能覆盖几乎所有需求。但是我爸觉得为了这么简单的需求买个电脑意义不大，一直在拖买电脑/学电脑的事情。

那我也忍不下去了，干脆声称Surface Book 2已经不能满足我写代码的性能要求，干脆丢给我爸。我声称自己可以用游戏本完成所有需要笔记本的工作。

这一切都很好，直到带着电脑开会，背着到处跑重不说，续航还是惨不忍睹，在会场上拿着大砖头到处找插座的就是我了。

加上游戏本，虽然是高刷屏，但是1080p写代码属于是折磨了，简而言之我需要更高清的屏幕，CPU性能不要输给一般游戏本太多，毕竟 `make -j$(nproc)` 对我的任意工作电脑是家常便饭了。最好还能PD充电，这样在回家高铁上抢不到插座可以接上我的充电宝。

= 买啥呢
我一直是决定要买啥东西之后，这东西必须在几天之内到手的性格。这个性格的成因可能和小时候家里声称考到xxx就买yyy却因为买的行为拖了一拖被强势的亲戚给阻止了yyy的兑现。（well，这儿yyy就是指电脑，亲戚觉得买了电脑我会沉迷游戏无心学习成为neet）

小时候的心理阴影按下不表，总而言之，我直接就梭哈了 `Lenovo ThinkBook 14 G5+ IRH`，本想买锐龙的笔记本，但是因为现在只有皮套CPU，正儿八经的 `zen4` 还没影，于是只能转向Intel。又本着亏自己不能亏电脑的心态自己上了 `i7-13700H+32G` 的版本。

= 到手后
#figure(
  caption: [ThinkBook 14+ 2022 的外观与接口],
  [
    #html.img(src: "https://cdn.yanqiyu.info/laptop/photo_2023-03-09_12-01-27.jpg")
    #html.img(src: "https://cdn.yanqiyu.info/laptop/photo_2023-03-09_12-01-26.jpg")
    #html.img(src: "https://cdn.yanqiyu.info/laptop/photo_2023-03-09_12-01-24.jpg")
    #html.img(src: "https://cdn.yanqiyu.info/laptop/photo_2023-03-09_12-01-23.jpg")
  ],
)

扩展性很不错，左侧一个全功能Type-C、一个雷电、一个普通的USB-A加上一个耳机口。右侧一个网线口（折叠的下侧盖子，插入网线不好拔）、一个普通的USB-A、SD插槽口，还有一个可以隐藏小接收器的USB仓（放无线鼠标接收器不会突出来一块）

预装Windows10家庭中文版，但这不管我的事，我的主要工作机怎么会运行Windows呢

= 折腾 Linux
装之前，先启动一个Fedora的LiveUSB看看八字合不合。然后结论是------不合，简单的说就是闪烁，都闪瞎了。随便上网搜索了下，找到了原因是PSR(Panel Self Refresh)八字不合。

== i915 PSR bug
#strike[搜寻过程不赘述，结论就是在这台机器上要在kernel cmdline加上 `i915.enable_psr2_sel_fetch=0` 才能正确的显示。算是给后人指路，虽然整个关了RSR也行，但是估计会耗电。]

无意间发现比较新的内核解决了这个问题，至少在 `38.20230403.0` 这个 `fedora/38/x86_64/testing/silverblue` 不会闪了。

== 电源管理支持
简单的说，很不错。Fedora自带的 `power-profiles-daemon` 相当的开箱即用。提供的`platform_profile` 我检查了一下是和BIOS设置里面的三种功耗模式对应的。

#figure(
  caption: [`powerprofilesctl` 显示的三种电源方案],
  [
```
powerprofilesctl list
  performance:
    Driver:     platform_profile
    Degraded:   no

* balanced:
    Driver:     platform_profile

  power-saver:
    Driver:     platform_profile
```
  ],
)

立刻写了个脚本，绑定到 `Fn+Q` 就可以用快捷键切换电源方案了。

#figure(
  caption: [绑定到 `Fn+Q` 的电源方案切换脚本],
  [
```bash
#!/bin/bash
# get current power profile
current_profile=$(powerprofilesctl get)
# if we are on battery
battery_status=$(cat /sys/class/power_supply/ADP1/online)
# if on battery, switch between balanced and power-saver
if [ $battery_status -eq 0 ]; then
    if [ $current_profile = "balanced" ]; then
        powerprofilesctl set power-saver
        notify-send "Power Profile" "Power Saver"
    else
        powerprofilesctl set balanced
        notify-send "Power Profile" "Balanced"
    fi
fi

# if on AC, switch between balanced and performance
if [ $battery_status -eq 1 ]; then
    if [ $current_profile = "balanced" ]; then
        powerprofilesctl set performance
        notify-send "Power Profile" "Performance"
    else
        powerprofilesctl set balanced
        notify-send "Power Profile" "Balanced"
    fi
```
  ],
)

== 电池“保护模式”
我也不知道咋个翻译，就是长期插电用的时候不把电充满的设计，启动就是 `echo 1 | sudo tee /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode` 关闭就是改成 `echo 0` 。

== 摄像头
有时候一些软件会把红外摄像头搞成优先，我不知道该怎么搞…

== 小bug
偶尔出现GPU hang，卡两秒左右恢复。

= 其他
因为装的是Silverblue于是之后会有些我如何在Silverblue上快乐玩耍的介绍和经验总结，都是后话了。

#html.hr()

最后是第一次见到Gnome鉴定为安全的设备，开眼了。

#figure(
  caption: [Gnome 将连接的 Thunderbolt 设备标记为安全],
  html.img(src: "https://cdn.yanqiyu.info/gnome.png"),
)
