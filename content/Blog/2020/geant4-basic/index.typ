#import "../../../../config.typ": template, tufted
#import "@preview/theorion:0.6.0": *
// 原文件: source/_posts/geant4-basic.md
// 原文时间: 2020-09-26 11:23:37
// tags: Geant 4
#let post = (
  title: [轻松的安装 Geant4],
  date: datetime(year: 2020, month: 9, day: 26),
  tag: ("Geant 4",),
  comments: true,
)
#show: template.with(..post)

#title()

#quote-block[
本文主要是给组里面的同学们快速配置自己的 Geant 4 之用
]

#quote-block[
本文使用 Fedora 操作系统（或者是其 WSL remix）
]

#quote-block[
如果你是高贵的 Arch 用户，AUR 里面貌似有现成的 Geant 4, 也是开箱即用的，但是 Arch 用户大概不需要这篇文章
]

= 在 WSL 中配置你的 Fedora 环境
对于原生 Linux 用户，请忽略这一节。

== 启用 WSL 与安装 Linux
请参阅#link("https://zhuanlan.zhihu.com/p/35801201")[这篇文章]的“为 WSL 做准备”章节，启用你的 Windows 下的 WSL。然后在#link("https://github.com/WhitewaterFoundry/Fedora-Remix-for-WSL/releases/tag/31.5.0")[Fedora Remix for WSL 发表页面]下载那个`appxbundle`文件，双击安装这个软件包，然后打开安装的程序，按照提示进行设置用户名以及密码。

== 安装 XServer
为了能正确使用 ROOT/Geant4 的图形界面，你需要安装 XServer。在#link("https://sourceforge.net/projects/vcxsrv/")[这里]下载，安装后启动，全部选择默认配置即可。

然后在 WSL 中运行

```bash
echo 'export DISPLAY=127.0.0.1:0' >> ~/.bashrc
```

== 伪装 release 信息
运行

```bash
sudo dnf install fedora-release --allowerasing 
```

WSL 配置至此结束，接下来是安装 Geant 4 以及 ROOT。

= 安装 Geant 4
运行

```bash
sudo dnf copr enable yanqiyu/geant4
sudo dnf install geant4 geant4-data geant4-devel geant4-examples
```

就完成了安装。

== 编译安装
#quote-block[
我不怎么建议自己编译安装，因为编译慢，安装的位置不好还需要手动设置一下环境变量
]

下载 Geant 4 的源代码，然后解压

```bash
mkdir build && cd build
cmake    -DGEANT4_BUILD_MULTITHREADED=ON \
         -DGEANT4_INSTALL_DATA=ON \
         -DGEANT4_USE_GDML=ON \
         -DGEANT4_USE_G3TOG4=ON \
         -DGEANT4_USE_QT=ON \
         -DOpenGL_GL_PREFERENCE=GLVND \
         -DGEANT4_USE_XM=ON \
         -DGEANT4_USE_OPENGL_X11=ON \
         -DGEANT4_USE_INVENTOR=OFF \
         -DGEANT4_USE_RAYTRACER_X11=ON \
         -DGEANT4_USE_SYSTEM_CLHEP=OFF \
         -DGEANT4_USE_SYSTEM_EXPAT=ON \
         -DGEANT4_USE_SYSTEM_ZLIB=ON \
         ..
make -jN（N 替换为你的 CPU 线程数）
make install
```

要是提示缺依赖就照着提示找依赖安装。

自己编译安装的版本需要运行：

```bash
source /path/to/geant4.sh
```

来设置环境变量，通过源安装的不需要。

= 安装 ROOT
在多数情况下，可以通过安装

```bash
sudo dnf install root-hist-painter root-physics root-mathmore root-tree-dataframe root-hist root-spectrum root-net root-tree-ntuple root-graf-x11 root-graf3d root-vecops root-matrix root root-multiproc root-icons root-tree root-graf-postscript root-gui root-graf-gpad root-tree-player root-cling root-minuit root-fonts root-graf-asimage root-graf root-core root-mathcore root-io root-gui-ged
```

就足以支撑大部分 Geant4 开发之用，要是 `cmake` 的时候提示缺文件就再安装就行。

= 基本程序框架
- `physicsList`, 一般是 `G4VModularPhysicsList` 以及其派生的预定义物理类型, 这个类负责定义模拟中的物理过程;
- `DetectorConstruction`, 派生自`G4VUserDetectorConstruction` 负责构建探测器的几何结构以及材料;
- `ActionInitialization` 派生自 `G4VUserActionInitialization`, 主要工作是对于模拟进行准备操作, 通过 `SetUserAction` 来实现注册各个其他运行相关的类, 在简单的程序中包括 `RunAction`, `EventAction`, `SteppingAction`, `PrimaryGeneratorAction` , 如果需要保存直方图的话就要加上 `HistoManager` \;
- `RunAction` 派生自 `G4UserRunAction`, 这个类定义了每个 run 的操作;
- `PrimaryGeneratorAction` , 派生自 `G4VUserPrimaryGeneratorAction` , 也就送描述粒子源的行为;
- `EventAction` 派生自 `G4UserEventAction`, 描述的是一个模拟的 Event 的过程, 一般处理的事情是按照设计统计每个 Step 中物理过程的能量沉积等数据, 并填充 tuple;
- `SteppingAction` 派生自 `G4UserSteppingAction`, 处理模拟过程每个 step, 每个 step 中 `UserSteppingAction` 都会被调用, 并传入一个 `G4Step` 参数, 可以获取这个 step 中的物理过程.
- `HistoManager`, 它一般是负责保存直方图到 `ROOT` 文件以供进一步操作的;
- 对于一些类来说, 还可以有它的 `messenger` 用于处理命令.
