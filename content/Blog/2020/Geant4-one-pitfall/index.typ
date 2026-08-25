#import "../../../../config.typ": template, tufted
// 原文件: source/_posts/Geant4-one-pitfall.md
// 原文时间: 2020-05-13 16:18:07
// tags: Geant 4
// math: true
#let post = (
  title: [Geant 4 的一个坑],
  date: datetime(year: 2020, month: 5, day: 13),
  tag: ("Geant 4",),
  comments: true,
)
#show: template.with(..post)

#title()

本文主题在 Geant 4 的官方论坛讨论#link("https://geant4-forum.web.cern.ch/t/step-action-tends-to-happen-at-certain-point/2489")[在此]. 感谢论坛用户 maire 没有它的提醒我现在还没走出代码苦海.

= 遇到问题
因为给最近在学习 Geant 4, 在老师的要求下准备写一个程序模拟获得质子行进的 $frac(upright(d) E, upright(d) x)$ 数据, 一开始我直接记录下每个 Step 的能量损失以及 `PostStepPoint` 对应的坐标. 然后对于质子穿透范围划成多个 bin, 将能量沉积填入其中.

但是事与愿违: 我得到了这样的直方图: #html.img(src: "https://cdn.yanqiyu.info/20200506185055.png")

它不正常, 一个质子行进的 $frac(upright(d) E, upright(d) x)$ 作图应该表现为单峰结构: #link("https://en.wikipedia.org/wiki/Bragg_peak")[Bragg Peak]. 但是可以看到在$x = 5 thin upright(c m)$ 上出现一个峰值.

OK, 出现了问题就去找问题.

= 寻找源头
#strong[理应]$x = 5 thin upright(c m)$附近不会有任何特殊性质, 至少在我的代码中 -- 说明问题出在 Geant 4, 我有什么地方用错了! 于是作图寻找什么与我的预期不一致:

#html.img(src: "https://cdn.yanqiyu.info/20200513163759.png") #html.img(src: "https://cdn.yanqiyu.info/20200513163953.png") 这两张图是我觉得提示了不一致的地方:

- 步长比我想象中的长, 我预期 $1 thin upright(c m)$ 长度会有数十次碰撞, 但是 Geant 4 追踪出现了数厘米的长度的 Step.
- 步长被截断, 在 $5 thin upright(c m)$ 附近.

OK, 问题成因就很容易了解了, 因为有相当事例的 Step 跨越了多个 bin, 并且有相当部分因为截断堆在了一起, 造成了一个 bin 取值很大.

== 查看源代码研究 `hIoni` 过程究竟怎么定义的
云里雾里的看了#link("https://github.com/Geant4/geant4")[这里]的众多代码 #strike[\(点名批评 VScode, 打开这个代码, 看一会, 我的内存就没了)], 勉强有了头绪.

- `G4hIonisation` 的基类是 `G4VContinuousDiscreteProcess`, 既包含连续过程又包含离散过程
- `G4hIonisation` 能量损失计算还是 `G4BetheBlochModel` 来计算

那么我们就对于 `G4hIonisation` 的行为有了一些图像了:

- 它通过 Bethe-Bloch 模型计算能量损失, 这是连续的(每厘米数十次碰撞体现在此处), 但是大多数碰撞损失能力很小, Geant 4不关心
- 对于能量较高的次级粒子, 比如$delta$-电子, 采取离散过程, 调用 `SteppingAction`, 这里我设置的 Hook 才会被调用, 而记录数据.

= 怎么平均?
现在我期望将跨越多个 bin 的数据平均到其跨越的每个 bin, 可惜, 这件事情很麻烦, 因为 `CERN ROOT` 遍历一个 `Tree` 不是很方便(你可以很轻松的从 `Tree` 中获得直方图, 但是要遍历 `Tree` 却没有提供迭代器, 只能靠 `TBranchAddress` 来遍历)

这个时候出现论坛回复, 告诉我 `TestEM11` 可以做一样的事情, 还没有我遇到的问题.

跑去看一眼 `TestEM11` 的代码:

```cpp
void SteppingAction::UserSteppingAction(const G4Step* step)
{
...
 //longitudinal profile of deposited energy
 //randomize point of energy deposotion
 //
 G4StepPoint* prePoint  = step->GetPreStepPoint();
 G4StepPoint* postPoint = step->GetPostStepPoint();
 G4ThreeVector P1 = prePoint ->GetPosition();
 G4ThreeVector P2 = postPoint->GetPosition();
 G4ThreeVector point = P1 + G4UniformRand()*(P2 - P1);
 if (step->GetTrack()->GetDefinition()->GetPDGCharge() == 0.) point = P2;
 G4double x = point.x();
 G4double xshifted = x + 0.5*fDetector->GetAbsorSizeX();
 analysisManager->FillH1(1, xshifted, edep);
...
}
```

马上干一样的事情:

#html.img(src: "https://cdn.yanqiyu.info/20200510175013.png") 修好了, 美妙.

= 经验
- 蒙特卡洛模拟的时候, 一个均匀的随机数可以充当平均
- 有些软件实现可能和物理直觉不一致, 用的时候不要根据物理自觉做过多假设
