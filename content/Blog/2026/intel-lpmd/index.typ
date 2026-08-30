#import "../../../../config.typ": template, tufted
#import "@preview/theorion:0.6.0": *

#let post = (
  title: [使用 `intel-lpmd` 实现 Intel 笔记本的进一步省电],
  tag: ("Linux"),
  date: datetime(year: 2026, month: 8, day: 29),
  comments: true,
)
#show: template.with(..post)

#title()

其实上下文是在升级到 Fedora 45 的预发行版本的时候，我都会简单的检查下 Fedora 上游的 rpm-ostree treefile 有什么更新值得注意。而这次我就注意到了 Fedora 45 的 treefile 相对于我上次检查多了个 `intel-lpmd` 的包，于是顺便研究了下这个包是干什么的。

根据名字，大概能猜出来和 _intel low power_ 什么什么的有关，然后迅速的看了下包的定义和上游的代码，觉得其功能其实非常有趣：
#quote-block[
  Intel Low Power Model Daemon is a Linux daemon used to optimize active idle
  power. It selects a set of most power efficient CPUs based on configuration
  file or CPU topology. Based on system utilization and other hints, it puts
  the system into Low Power Mode by activating the power efficient CPUs and
  disabling the rest, and restoring the system from Low Power Mode by activating
  all CPUs.  
]
简而言之，就是当系统处于idle状态的时候，就将剩余的进程限制到部分CPU上，允许更多的核心进入休眠状态来省电。

听起来很好，得用上。

= 配置这么个工具
安装包很简单，日常的系统就 `dnf install`/`rpm-ostree install` 我也就是相应的把这个包加到我的 treefile, 然后构建完成之后应用更新。然后#sym.dots 发现这东西默认情况下啥都不会干。检查后发现，默认的配置文件就等于告诉这个daemon什么都不要做——需要手动启用。

#figure(
  caption:[
    `/etc/intel_lpmd/intel_lpmd_config_F{1}_M{2}.xml`，其中 `{1}` 和 `{2}` 是 CPU 的 family 和 model，可以通过 `lscpu` 命令查看。
  ],
  [
    ```xml
    <?xml version="1.0"?>
    
    <Configuration>
        <!-- 留空：自动选择最节能的 E-core 模块 -->
        <lp_mode_cpus></lp_mode_cpus>
    
        <!-- 不覆盖 tuned/intel_pstate 设置的 EPP -->
        <lp_mode_epp>-1</lp_mode_epp>
    
        <!-- systemd cgroup v2 -->
        <Mode>0</Mode>
    
        <!-- performance 下完全关闭 LPM -->
        <PerformanceDef>-1</PerformanceDef>
    
        <!-- balanced/power-saver 下按利用率自动切换 -->
        <BalancedDef>0</BalancedDef>
        <PowersaverDef>0</PowersaverDef>
    
        <!-- 先使用可靠的利用率检测 -->
        <HfiLpmEnable>0</HfiLpmEnable>
        <WLTHintEnable>0</WLTHintEnable>
    
        <!-- 整机负载低于 10% 时尝试进入 LPM -->
        <util_entry_threshold>10</util_entry_threshold>
    
        <!-- LPM CPU 中最忙 CPU 超过 95% 时恢复所有 CPU -->
        <util_exit_threshold>95</util_exit_threshold>
    
        <IgnoreITMT>1</IgnoreITMT>
    </Configuration>
    ```
  ])<conf>
在更新的支持所谓 workload hint 的平台，这个软件似乎还有更多花样——但是因为我的笔记本不支持，于是就放弃折腾更多细节了。

= 当前这个工具的问题
经过一段时间的尝试，我发现这个软件默认禁用是有道理的。其最大的问题是切换到低功耗模式和切换回来的条件没有任何防抖。比如在 @conf 的配置文件下，LPM生效的条件就是系统负载低于10%，退出条件是系统负载高于10%或者LPM CPU中最忙的CPU负载高于95%。而在我的系统下，简单的浏览器负载，存在很多瞬时的负载波动，导致这个软件频繁的切换CPU状态（约1Hz的频率），对应于频繁的迁移IRQ以及破坏进程已有的缓存，导致我其实很怀疑这个软件的实际省电效果。

在其配置文件似乎有防抖的参数：
#figure(
  caption:[配置文件里面看到的参数],
  [
    ```xml
    <EntryDelayMS>...</EntryDelayMS>
    <ExitDelayMS>...</ExitDelayMS>
    <EntryHystMS>...</EntryHystMS>
    <ExitHystMS>...</ExitHystMS>
    ```
  ]
)
但是现在这些参数只是能被parse，没有在决定策略的时候生效。

此外，如果觉得只在只开一个小核簇和全核都开的两种状态切换太过激进的话，这个软件其实允许定义不同的 `<State>` 来实现更多的状态切换，不过这个功能现在#link("https://github.com/intel/intel-lpmd/issues/126")[也有自己的 bug]。

= 结论
现在我真正在用的配置是 
#figure(
  caption:[
    在 powersave 模式下，绑定到两个小核簇的 CPU 是 12-19，其他 CPU 都不使用。在其他模式下完全关闭 LPM。
  ],
  [
    ```xml
    <?xml version="1.0"?>
    
    <Configuration>
        <lp_mode_cpus>12-19</lp_mode_cpus>
    
        <!-- 不覆盖 tuned/intel_pstate 设置的 EPP -->
        <lp_mode_epp>-1</lp_mode_epp>
    
        <!-- systemd cgroup v2 isolate -->
        <Mode>1</Mode>
    
        <!-- performance 下完全关闭 LPM -->
        <PerformanceDef>-1</PerformanceDef>
    
        <BalancedDef>-1</BalancedDef>
        <PowersaverDef>1</PowersaverDef>
    
        <IgnoreITMT>1</IgnoreITMT>
    </Configuration>
    ```
  ]
)
算是一个巨大的折中，更进一步的改进得等这个软件正确的实现了防抖和多状态切换功能之后再说了。
