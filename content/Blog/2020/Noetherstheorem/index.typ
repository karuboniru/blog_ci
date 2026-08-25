#import "../../../../config.typ": template, tufted
#import "@preview/theorion:0.6.0": *
#import "@preview/physica:0.9.8": *
// 原文件: source/_posts/Noetherstheorem.md
// 原文时间: 2020-03-30 21:33:47
// tags: 学习
// math: true
#let post = (
  title: [诺特定律],
  date: datetime(year: 2020, month: 3, day: 30),
  tag: ("学习",),
  comments: true,
)
#show: template.with(..post)

#title()

诺特定律, 也即对称性蕴含守恒流, 更加准确的说法是

每一个局部作用的可微的对称性, 都蕴含某种守恒流.

= 什么是守恒流
守恒流是满足: $ partial_mu j^mu = 0 $ 的一个场.

= 场在对称变换下的描述
而对称性的考量数学上就有两种看法

- 主动视角, 对应参照系不变, 物理点运动;
- 被动视角, 物理点不变, 参照系运动.

接下来我们会更加自然的考虑后者, 因为后者更加容易给出明确的数学表示.

也就是时空点$P$, 坐标$x^mu$, 场$f (x^mu)$, 变为坐标$x' ^mu$, 场$f' (x' ^mu)$,

考虑在一个无穷小变换$x' arrow.r x + delta x$下, 场的变换可以写作: $ delta f & = f' \( x' ^mu \) - f \( x^mu \)\
 & = f' \( x^mu + delta x^mu \) - f \( x^mu \)\
 & = f' \( x^mu \) - f \( x \) + delta x^mu partial_mu f' \( x^mu \) + cal(O) \( delta x^2 \)\
 & = f' \( x^mu \) - f \( x \) + delta x^mu partial_mu f \( x^mu \) + cal(O) \( delta x^2 \) $

而$partial_mu f'$被换成$partial_mu f$带来的差异不会大于$delta x$的一阶. 并定义$f' \( x^mu \) - f \( x \)$为$delta_0 f$从而可以写出: $ delta f = delta_0 f + delta x^mu partial_mu f $ 或者说 $ delta = delta_0 + delta x^mu partial_mu $ 其中$delta_0 f$表述场本身的变化, 而$delta x^mu partial_mu f$表示由于点坐标的变化带来的变化.

#quote-block[
对于时空平移变换$x' ^mu = x^mu + a^mu \, thin delta phi.alt = 0$

此时有 $ delta_0 phi.alt = - a^mu partial_mu phi.alt $ 其实这就对应于场在平移下的变换: $ phi.alt' \( x^mu \) = phi.alt \( x^mu - a^mu \) $
]

在此之外, 场可能有内禀变换, 此时$delta x = 0$, 变化的只有场.

= 诺特流的推导
考虑一个场, 其作用量可以写作 $ S \( phi.alt \( x \) \) = integral upright(d)^4 x cal(L) \( phi.alt \, partial_mu phi.alt \, x \) $

系统的演化路径遵循$delta S = 0$, 则: $ 0 = delta S & = integral [delta \( upright(d)^4 x \) cal(L) + upright(d)^4 x delta cal(L)]\
 & = integral upright(d)^4 x \( partial_mu delta x^mu cal(L) + delta cal(L) \) $ 而根据前文以及链式法则 $ delta cal(L) & = delta x^mu partial_mu cal(L) + delta_0 cal(L)\
 & = delta x^mu partial_mu cal(L) + frac(partial cal(L), partial phi.alt) delta_0 phi.alt + frac(partial cal(L), partial \( partial_mu phi.alt \)) delta_0 \( partial_mu phi.alt \)\
 & = delta x^mu partial_mu cal(L) + [frac(partial cal(L), partial phi.alt) - partial_mu frac(partial cal(L), partial \( partial_mu phi.alt \))] delta_0 phi.alt + partial_mu (frac(partial cal(L), partial \( partial_mu phi.alt \)) delta_0 phi.alt) $ 最后一步是使用了分部积分, 并且使用了$delta_0 \( partial_mu phi.alt \) = partial_mu \( delta_0 mu phi.alt \)$. 同时注意到有: $ frac(partial cal(L), partial phi.alt) - partial_mu frac(partial cal(L), partial \( partial_mu phi.alt \)) = 0 $ 这是场的欧拉-拉格朗日运动方程. 则 $ 0 = delta S & = integral upright(d)^4 x partial_mu (delta x^mu cal(L) + frac(partial cal(L), partial \( partial_mu phi.alt \)) delta_0 phi.alt) $ 考虑到变分的任意性, 则有$partial_mu (delta x^mu cal(L) + frac(partial cal(L), partial \( partial_mu phi.alt \)) delta_0 phi.alt) = 0$, 对扩号内的部分使用$delta_0 = delta - delta x^mu partial_mu$, 则:

$ 0 = delta S & = integral upright(d)^4 x partial_mu [cal(L) delta x^mu + frac(partial cal(L), partial \( partial_mu phi.alt \)) \( delta - delta x^nu partial_nu \) phi.alt]\
 & = integral upright(d)^4 x partial_mu [(cal(L) delta_mu^nu - frac(partial cal(L), partial \( partial_mu phi.alt \)) partial_nu phi.alt) delta x^nu + frac(partial cal(L), partial \( partial_mu phi.alt \)) delta phi.alt] $ 这样, 就得到了一个守恒流, 也就是本文的核心: $ j^mu = (cal(L) delta_mu^nu - frac(partial cal(L), partial \( partial_mu phi.alt \)) partial_nu phi.alt) delta x^nu + frac(partial cal(L), partial \( partial_mu phi.alt \)) delta phi.alt $

== 诺特荷
对于一个在有限空间内分布的流(无穷远处, 场应该趋近于零, 这是其物理意义要求的), 考虑场的等时变分 $ 0 & = integral upright(d)^4 x partial_mu j^mu\
  & = integral_(t_1)^(t_2) dd(x^0) integral dd(x^3) (partial_0 j^0 + nabla dot.op arrow(j))\
 & = integral_(t_1)^(t_2) dd(x^0) partial_0 integral upright(d)^3 x j^0\
 & = Q \( t_2 \) - Q \( t_1 \) $

则$Q = integral upright(d)^3 x j^0$就是诺特荷, 是在这个对称性给出的守恒量.

= 举例
对于时空平移变换的特殊情况:

#quote-block[
平移变换具有各向同性(说人话就是朝着时空四个轴有四个#strong[生成元]) 那么, 诺特流就会升级成为能量动量张量 原来的守恒流长这样 $ j^mu = (cal(L) delta_mu^nu - frac(partial cal(L), partial \( partial_mu phi.alt \)) partial_nu phi.alt) delta x^nu + frac(partial cal(L), partial \( partial_mu phi.alt \)) delta phi.alt $ 去掉场的本身的变换:$delta phi.alt = 0$, 考虑到$delta x^nu = a^nu$的任意性 $ partial_mu (cal(L) delta_mu^nu - frac(partial cal(L), partial \( partial_mu phi.alt \)) partial_nu phi.alt) = 0 $ 这就是场论的能量动量张量: $ T_nu^mu = (- cal(L) delta_mu^nu + frac(partial cal(L), partial \( partial_mu phi.alt \)) partial_nu phi.alt)\
T^(mu nu) = (- cal(L) eta^(mu nu) + frac(partial cal(L), partial \( partial_mu phi.alt \)) partial^nu phi.alt) $
]

对于一个场的内禀变换而言, 比如复 Klein-Gordon 场的$U \( 1 \)$对称性

#quote-block[
$ phi.alt & arrow.r upright(e)^(i alpha) phi.alt\
phi.alt^(*) & arrow.r upright(e)^(- i alpha) phi.alt^(*) $ 借助生成元$delta phi.alt = i phi.alt \, thin delta phi.alt^(*) = i phi.alt^(*)$, 可以写出 $ j^mu = i [\( partial^mu phi.alt^(*) \) phi.alt - phi.alt^(*) \( partial^mu phi.alt \)] $ 它对应的守恒荷就是: $ Q = integral upright(d)^3 x j^0 = i integral upright(d)^3 x (dot(phi.alt)^(*) phi.alt - phi.alt^(*) dot(phi.alt)) $ 可以通过正则量子化计算发现这个守恒就对应电荷守恒.
]
