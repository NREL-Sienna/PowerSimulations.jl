# PowerSimulations.jl

```@meta
CurrentModule = PowerSimulations
```

## Overview

The package supports two major analysis tools:

- Operational Models: Meant to study and analyze multiperiod operational model formulations that can be specified by the combination of device formulations and network models.
- Simulations Models: Developed to run sequences of operational models to study model interactions such as cost-production-modeling.

The main features include:

- This feature
- That feature

`PowerSimulations.jl` documentation and code are organized according to the needs of different users depending on their skillset and requirements. In broad terms there are three categories:

- **Modeler**: Users that want to solve an operations problem  or run a simulation using the existing models in `PowerSimulations.jl`.

- **Model Developer**: Users that want to develop custom models and workflows for

- **Code Base Developers**: Users that want to add new core functionalities or fix bugs in the core capabilities of `PowerSimulations.jl`.

`PowerSimulations.jl` is an active project under development, and we welcome your feedback,
suggestions, and bug reports.

**Note**: `PowerSimulations.jl` uses the data model implemented in [`PowerSystems.jl`](https://github.com/NREL/PowerSystems.jl) to construct optimization models. In most cases, you need to add `PowerSystems.jl` to your
scripts

## Installation

The latest stable release of PowerModels can be installed using the Julia package manager with

```julia
] add PowerSimulations
```

For the current development version, "checkout" this package with

```julia
] add PowerSimulations#master
```

An appropriate optimization solver is required for running PowerSimulations models. Refer to [`JuMP.jl` solver's page](http://www.juliaopt.org/JuMP.jl/v0.20.0/installation/#Getting-Solvers-1) to select the most appropriate for the application of interest.

------------
PowerSystems has been developed as part of the Scalable Integrated Infrastructure Planning
(SIIP) initiative at the U.S. Department of Energy's National Renewable Energy
Laboratory ([NREL](https://www.nrel.gov/)).
