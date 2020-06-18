# PowerSimulations.jl

```@meta
CurrentModule = PowerSimulations
```

### Overview

PowerSimulations.jl is a Julia/JuMP package designed to develop and study power system operation models in steady-state. It uses the data model implemented in [`PowerSystems.jl`](https://github.com/NREL/PowerSystems.jl) to construct optimization models.

The package supports to major analysis tools.

 - Operational Models: Meant to study and analyze multiperiod operational model formulations that can specified by the combination of device formulations and network models.
 - Simulations Models: Developed to run sequences of operational models to study model interactions sucha as cost-production-modeling.

 The documentation is still work in progress.


## Installation

The latest stable release of PowerModels can be installed using the Julia package manager with

```julia
] add PowerSimulations
```

For the current development version, "checkout" this package with

```julia
] add PowerSimulations#master
```

An appropiate optimization solver is required for running PowerSimulations models. Refer to [`JuMP.jl` solver's page](http://www.juliaopt.org/JuMP.jl/v0.20.0/installation/#Getting-Solvers-1) to select the most appropiate for the application of interest.
