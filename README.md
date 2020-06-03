
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![DOI](https://zenodo.org/badge/147096983.svg)](https://zenodo.org/badge/latestdoi/147096983)

# CurricularVisualization.jl
**CurricularVisualization.jl** is an extension of the CurricularAnalytics.jl toolbox for visualizing curricula and degree plans. 

## Documentation
Full documentation is available at CurricularAnalytics.jl [GitHub Pages](https://curricularanalytics.github.io/CurricularAnalytics.jl/latest/).

# Installation

Installation is straightforward.  First, install the Julia programming language on your computer.  To do this, download Julia here: https://julialang.org, and follow the instructions for your operating system.

Next, open the Julia application that you just installed. It should look similar to the image below. This interface is referred to as the `Julia REPL`.

![Julia termain](https://s3.amazonaws.com/curricularanalytics.jl/julia-command-line.png)

Next, enter Pkg mode from within Julia by hitting the `]` key, and then type:
```julia-repl
  pkg> add CurricularAnalytics CurricularVisualization
```
This will install the CurricularAnalytics toolbox (if not already installed) and the visualization software, along with the other Julia packages needed to run it. To load and use the visualization, hit the `backspace` key to return to the Julia REPL. Now type:
```julia-repl
  julia> using CurricularAnalytics, CurricularVisualization
```
The visualization software must be loaded again via `using CurricularAnalytics, CurricularVisualization` every time you restart Julia.

For more information about installing the toolbox, including the steps neccessary to utilize degree plan optimization, please see the [INSTALLING.md](https://curricularanalytics.github.io/CurricularAnalytics.jl/latest/install.html)

## Supported Versions
* CurricularVisualization will be maintained/enhanced to work with the latest stable version of Julia.
* Julia Version(s): CurricularVisualization v0.1.0 is the latest version guaranteed to work with Julia 1.4
* Later versions: Some functionality might not work with prerelease / unstable / nightly versions of Julia. If you run into a problem, please file an issue.

# Contributing and Reporting Bugs
We welcome contributions and bug reports! Please see [CONTRIBUTING.md](https://github.com/CurricularAnalytics/CurricularAnalytics.jl/blob/master/CONTRIBUTING.md)
for guidance on development and bug reporting.
