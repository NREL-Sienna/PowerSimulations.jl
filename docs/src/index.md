# PowerSimulations.jl

### Overview

PowerSimulations.jl is a Julia/JuMP package designed to develop and study power system operation models in steady-state. It uses the data model implemented in [`PowerSystems.jl`](https://github.com/NREL/PowerSystems.jl) to construct optimization models.

The package supports two major analysis tools:

- Operational Models: Meant to study and analyze multi-period operational model formulations that can be specified by the combination of device formulations and network models.
- Simulations Models: Developed to run sequences of operational models to study model interactions such as cost-production-modeling.

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

An appropriate optimization solver is required for running PowerSimulations models. Refer to [`JuMP.jl` solver's page](http://www.juliaopt.org/JuMP.jl/v0.20.0/installation/#Getting-Solvers-1) to select the most appropriate for the application of interest.
