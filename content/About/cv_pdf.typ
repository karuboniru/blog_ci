#show link: underline
#set text(
  size: 12pt,
  font: ("Libertinus Serif", "FandolKai", "Zhuque Fangsong (technical preview)", "Noto Serif CJK SC"),
  fallback: false,
)
// #show raw: set text(font: "Libertinus Mono")
#set page(
  margin: (x: 1.0cm, y: 1.5cm),
  // footer: text(gray)[
  //   #align(right)[
  //     Last updated: #datetime.today().display("[year]/[month]/[day]"). #link("https://share.niconi.org/cv.pdf")[Check for updates]
  //   ]
  // ],
)
#set par(justify: true)
#let chiline() = {
  v(-3pt)
  line(length: 100%)
  v(-5pt)
}
#import "@preview/physica:0.9.3": *

#let nuwro = smallcaps([NuWro])
= Qiyu Yan 严启宇

#link("mailto:yanqiyu17@mails.ucas.ac.cn")[yanqiyu17\@mails.ucas.ac.cn]
| Chinese Citizen
// | #link("https://github.com/karuboniru")[GitHub: karuboniru]
| #link("https://orcid.org/0009-0005-0796-5539")[ORCiD: 0009-0005-0796-5539]

== Education
#chiline()

*Tsung-Dao Lee Institute* #h(1fr) 2026/07 -- Expected 2026/09 \
Visiting Fellow #h(1fr) Shanghai, China 

*University of Warwick* #h(1fr) 2023/06 -- 2024/05, 2025/08 - 2026/05 \
Visiting Ph.D. Student in Physics #h(1fr) Coventry, UK \
Supervisor: Prof. Xianguo Lu

*University of Chinese Academy of Sciences* #h(1fr) 2021/09 - 2026/06 \
Ph.D. in Physics #h(1fr) Beijing, China \
Supervisor: Prof. Xianguo Lu (Warwick), Prof. Yangheng Zheng

*University of Chinese Academy of Sciences* #h(1fr) 2017/09 -- 2021/06 \
B.Sc. in Physics #h(1fr) Beijing, China \
- Core Course GPA: *3.88/4.0* #h(1fr) #link("https://share.niconi.org/Thesis.pdf")[Link to thesis]

#let item-header(content, time-info) = {
  grid(
    columns: (1fr, auto),
    align: (left, right),
    inset: 0pt,
    gutter: 0pt,
    row-gutter: 0pt,
    column-gutter: 10pt,
    [#content],
    [#time-info]
  )
  v(-0.5em)
}

== Projects
#chiline()
#item-header([*Understanding the impact of nuclear effects on proton decay searches with the #smallcaps[GiBUU] model*],  [2025 -- 2026]) 
Supervisor: Prof. Xianguo Lu \
- I used the GiBUU framework to reevaluate the proton decay search sensitivity for the $p arrow e^+ pi^0$ channel in water Cherenkov detectors like Hyper-Kamiokande, incorporating realistic event reconstruction performance.
- The study examines how different initial-state and medium effects affecting $pi N$ or $N N$ scattering, such as short-range correlations and $Delta$-resonance broadening, affect the signal efficiency and background rates, providing insights into the overall uncertainty in proton decay sensitivity.
- Demonstrated that GiBUU provides a self-consistent framework for modeling nuclear effects in both signal and background, enabling future consideration of correlated systematic uncertainties essential for an unbiased proton lifetime extraction.
- The resulting sensitivity estimate for Hyper-Kamiokande is consistent with previous studies at the \~10% level, validating the framework for next-generation searches.

#item-header([*Understanding neutrino pion production with the GiBUU model*],  [2024 -- 2025])
Supervisor: Prof. Xianguo Lu \
- I performed a comprehensive study of neutrino-induced pion production using the GiBUU model, comparing its predictions with data from MINERvA, MicroBooNE, and T2K experiments.
- Identified tension between GiBUU predictions and experimental data, particularly in the treatment of $2pi$ background contributions and $Delta$-resonance broadening effects, showing the complicated nature of in-medium effects.

// *#smallcaps([Professor2])-Based ReWeight for GENIE* #h(1fr) 2023 -- Present \
#item-header([*#smallcaps([Professor2])-Based ReWeight for GENIE*],  [2023 -- Present]) 
Supervisor: Prof. Xianguo Lu, Prof. Constantinos Andreopoulos \
- I build the tool to perform parameterization of predicted differential cross-section with interpolation framework #smallcaps([Professor2]) for
  for hadronization and FSI parameters in GENIE neutrino event generator.
- This tool enables the reweighting of these parameters, which were previously considered unreweightable but represent significant sources of model uncertainty in meson-production and DIS regions.

#item-header([*The Ghent Hybrid Model in #smallcaps([NuWro])*],  [2023 -- 2024]) 
Supervisor: Prof. Xianguo Lu \
- I implemented the Ghent Hybrid Model for single-pion production in #nuwro neutrino event generator, the new model provides an improved description of resonance contributions and related backgrounds in several $"GeV"$ hadronic invariant mass region.
- The new model is benchmarked with MINERvA, MicroBooNE and T2K data, showing significant improvement in describing the data.

#item-header([ _B.Sc. Thesis:_ *Physics Sensitivity Study with GeV Neutrinos in JUNO*],  [2020 -- 2021]) 
Supervisor: Dr. Xianguo Lu (Oxford), Prof. Yangheng Zheng \
// Thesis topic:
- I studied the sensitivity of Jiangmen Underground Neutrino Observatory (JUNO) to neutrino mass ordering problem using atmospheric neutrinos.
- The study includes the following steps:
  - Calculate the atmospheric neutrino event rate using flux from Honda et al. and GENIE neutrino event generator, and
    oscillation probability from the oscillation calculation tool #smallcaps([Prob3]).
  - For the predicted final state, the energy deposit is simulated using GEANT4, with a mock detector geometry of JUNO, to estimate the energy resolution.
  - Using the estimated energy resolution and angular resolution, calculate the sensitivity of JUNO to neutrino mass ordering problem.
- The main contributions of my thesis are:
  - Contribute a full chain of sensitivity study of JUNO to neutrino mass ordering problem using atmospheric neutrinos.
  - Framework contributes to the future atmospheric neutrino studies in JUNO.
// - Use Honda flux and GENIE generator to predict the event rate and final state particles of atmospheric neutrino interactions in JUNO detector.
// - Use #smallcaps([Prob3]) to calculate the oscillation probability for different oscillation parameters.
// - Use GEANT4 to simulate the propagation of final state particles in JUNO detector, to estimate the energy resolution.
// - Use estimated energy resolution and angular resolution to calculate the sensitivity of JUNO to neutrino mass ordering problem.

#item-header([ _Summer Project:_ *GEANT4 Based Simulation of Time Projection Chamber*],  [2020/07 - 2020/09]) 
Supervisor: Dr. Xianguo Lu (Oxford) \
// Topic:
- I studied the behavior of different particles going through a Time Projection Chamber (TPC) detector using GEANT4 simulation toolkit.
- The study includes the following steps:
  - Use GEANT4 to simulate the behavior of different particles (electron, muon, proton, pion, alpha) going through a TPC detector.
  - Record the energy deposit $dv(E,x, s:slash)$ and track length for different particles.
  - Analyze the Bragg peak behavior and the dependence on the energy deposit of track length for different particles.
- The main contributions of my project are:
  - Provide a detailed study of the behavior of different particles going through a TPC detector using GEANT4 simulation toolkit.
  - Observed different Bragg peak behavior from different particles, which may be used to conduct particle identification in TPC detector.
  - Observed the dependence on the energy deposit of track length, which may be used to conduct energy measurement in TPC detector.
// - Use GEANT4 to simulate the behavior of different particles going through a TPC detector, record the energy deposit $dv(E,x, s:slash)$ and track length.
// - Observed different Bragg peak behavior from different particles, which may be used to conduct particle identification in TPC detector.
// - Observed the dependence on the energy deposit of track length, which may be used to conduct energy measurement in TPC detector.

== Collaborations and Roles
#chiline()
- GENIE Collaboration #h(1fr) 2023 -- Present
  - Bug fix for hadronization model `AGKYLowW2019` directionality issue #link("https://github.com/GENIE-MC/Generator/issues/226")[(GENIE-MC/Generator:226)]
  - Development of #smallcaps([Professor2])-based ReWeight tool for hadronization and FSI parameters.
- JUNO Collaboration #h(1fr) 2021 -- Present
  - Gev v-A high-eNergY MEDium Effect (GANYMEDE) Working Group
    - Generator Task Lead: #h(1fr) 2023 -- Present
      - Development and maintenance of GENIE and #nuwro neutrino event generator interface in JUNO software framework.
      - Metropolis-Hastings-based sampling algorithm for #nuwro event generation.
      - 3D flux handling for #nuwro event generation.
      - Development of automated model comparison and validation framework for GeV neutrino event generators in JUNO.
      - Contribute to the atmospheric neutrino simulation production by managing the Monte Carlo production software.
      - Collect bug report from user and contribute to the development of different neutrino event generator.
    - Proposed the selection of baseline model for atmospheric neutrino interaction analyses in JUNO.
    - Proposed the strategy for cross-section-related systematic uncertainty evaluation for atmospheric neutrino analyses in JUNO.
    - Provided suggestion to analyses with atmospheric neutrinos induced backgrounds, such as diffuse supernova neutrino background and invisible nucleon decay searches.
  - Atmospheric Neutrino Working Group
    - Provided Bayesian estimation of mass ordering sensitivity to complement the frequentist approach.
    - Joined the statistical-only frequentist mass ordering sensitivity study.
    - Contribute to the establishment of common input for atmospheric neutrino flux, cross-section, and oscillation input.
    - Evaluation of the cross-section-related systematic uncertainties for atmospheric neutrino reconstruction tasks (including flavor identification and energy resolution).
  - Reactor Neutrino Working Group
    - Development of GPU-accelerated calibration fit framework, used in #super[68]Ge calibration data analysis of Group B.
      // - Contributed to the selection of the baseline interaction model for atmospheric neutrino analyses in JUNO.
      // - Developed cross-section-related systematic uncertainty inputs for reconstruction tasks and sensitivity studies.
      // - Provided Bayesian estimation of mass ordering sensitivity to complement the frequentist approach.
// - GENIE Collaboration #h(1fr) 2023 -- Present
//   - Develop new ReWeight tool.
// - JUNO Collaboration #h(1fr) 2021 -- Present
//   - GANYMEDE PWG: work on GeV generator integration to JUNO software and incorporating up-to-date neutrino interaction models with JUNO.
//   - Generator Task Lead: #h(1fr) 2023 -- Present
//     - GENIE:
//       - Development: `AGKYLowW2019` directionality bug fix #link("https://github.com/GENIE-MC/Generator/issues/226")[(GENIE-MC/Generator:226)]
//     - #nuwro:
//       - Development:
//         - 3D atmospheric flux interface
//         - Metropolis-Hastings-based sampling algorithm
//         - Ghent single-pion-production model (#link("https://arxiv.org/abs/2405.05212")[arXiv: 2405.05212 [hep-ph]])
//       - Bugfix:
//         // - #nuwro might crash in rare case with numeric error (JUNO internal)
//         - 2D atmospheric mixed flavor flux handling #link("https://github.com/NuWro/nuwro/pull/32")[(NuWro/nuwro:32)]
//       - Internalisation in JUNO
//       - Benchmarking
//     - #smallcaps[GenNuWro] (#nuwro wrapper in JUNO)
//       - Development
//     - MC production
//       - Management and execution
//   - Development of quality control tools for Monte Carlo sample

== Conferences
#chiline()
Invited Talk: Qiyu Yan, _Understanding the impact of nuclear effects on proton decay searches with the #smallcaps[GiBUU] model_, *NOW 2026* #h(1fr) #link("https://agenda.infn.it/event/50058/contributions/299927/")[Otranto Italy 2026/09]

Invited Talk: Qiyu Yan, _The Ghent Hybrid Model in #smallcaps([NuWro]): a new neutrino single-pion production model in the GeV regime_, *15th International Workshop on Neutrino-Nucleus Interactions* #h(1fr) #link("https://indico.fnal.gov/event/64969/contributions/317922/")[Mainz Germany 2025/10]

Talk: Qiyu Yan, _Atmospheric neutrino oscillations in JUNO_, *NuFact 2025 - The 26th International Workshop on Neutrinos from Accelerators* #h(1fr) #link("https://indico.cern.ch/event/1528564/contributions/6619092/")[Liverpool UK 2025/09]

Talk: Qiyu Yan, _Understanding neutrino pion production with the GiBUU model_, *NuFact 2025 - The 26th International Workshop on Neutrinos from Accelerators* #h(1fr) #link("https://indico.cern.ch/event/1528564/contributions/6624107/")[Liverpool UK 2025/09]

Talk: Qiyu Yan, _Modeling pion production for GeV neutrino experiments_, *The 23rd International Conference on Few-Body Problems in Physics* #h(1fr) #link("https://indico.ihep.ac.cn/event/21083/contributions/166733/")[Beijing China 2024/09]

Poster: Qiyu Yan _et al._, _Medium effect in Sensitivity of Proton Decay Search_, *15th International Workshop on Neutrino-Nucleus Interactions* #h(1fr) #link("https://share.niconi.org/pdk_poster.pdf")[Mainz Germany 2025/10]

Poster: Qiyu Yan _et al._ on behalf of GENIE Collaboration, _Professor Based ReWeight for GENIE Generator_, *NEUTRINO2024*. #h(1fr) #link("https://agenda.infn.it/event/37867/contributions/227745/")[Milan Italy 2024/06]

Poster: Qiyu Yan _et al._ on behalf of GANYMEDE PWG,
_Status of the GANYMEDE Working Group for GeV Physics at JUNO_, *NEUTRINO2022*. #h(1fr) #link("https://indico.kps.or.kr/event/30/contributions/297/")[Seoul Korea (online) 2022/06]

== Selected Publications (4 selected from 17)
#chiline()
Qiyu Yan, Akira Takenaka, Kai Gallmeister, Xianguo Lu, Ulrich Mosel, Yangheng Zheng, _Understanding the impact of nuclear effects on proton decay searches with the #smallcaps[GiBUU] model_, #link("https://doi.org/10.1103/zgxd-zy7j")[Phys. Rev. D 113, 095039] #link("https://arxiv.org/abs/2602.23063")[`[hep-ex/2602.23063]`] #link("https://inspirehep.net/literature/3123880")[#smallcaps([[inSPIRE]])]


Qiyu Yan, Kaile Wen, Kai Gallmeister, Xianguo Lu, Ulrich Mosel, Yangheng Zheng, _Understanding neutrino pion production with the GiBUU model_, #link("https://doi.org/10.1103/yzqx-7ttd")[Phys. Rev. D 112, 093007] #link("https://arxiv.org/abs/2507.20539")[`[hep-ex/2507.20539]`]#link("https://inspirehep.net/literature/2954715")[#smallcaps([[inSPIRE]])]
// - First author of this paper, I performed a comprehensive study of neutrino-induced pion production using the GiBUU model, comparing its predictions with data from MINERvA, MicroBooNE, and T2K experiments.
// - Identified tension between GiBUU predictions and experimental data, particularly in the treatment of $2pi$ background contributions and $Delta$-resonance broadening effects, showing the complicated nature of in-medium effects.

Qiyu Yan, Kajetan Niewczas, Alexis Nikolakopoulos, Raúl González-Jiménez, Natalie Jachowicz, Xianguo Lu, Jan Sobczyk, Yangheng Zheng, _The Ghent Hybrid Model in #smallcaps([NuWro]): a new neutrino single-pion production model in the GeV regime_, #link("https://doi.org/10.1007/JHEP12(2024)141")[JHEP 12 (2024) 141] #link("https://arxiv.org/abs/2405.05212")[`[hep-ph/2405.05212]`] #link("https://inspirehep.net/literature/2784425")[#smallcaps([[inSPIRE]])]
// - First author of this paper, I implemented the Ghent Hybrid Model for single-pion production in #nuwro neutrino event generator, benchmarked it with different experimental data sets.
// - The new model provides consistent and improved description of resonance contributions and related backgrounds in several $"GeV"$ hadronic invariant mass region.
// - The new model is adopted as the default resonance model in #nuwro starting from version 25.03.

Angel Abusleme _et al._ (JUNO Collaboration), _Initial performance results of the JUNO detector_, #link("https://arxiv.org/abs/2511.14590")[`[hep-ex/2511.14590]`] #link("https://inspirehep.net/literature?q=eprint+2511.14590")[#smallcaps([[inSPIRE]])]
// - I contributed to the cross check phase of different reconstruction algorithms by providing a GPU accelerated calibration fit framework, which is used in multiple
//   calibration data analyses in JUNO Group B.
