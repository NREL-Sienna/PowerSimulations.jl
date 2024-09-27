# PowerSimulations.jl

```@meta
CurrentModule = PowerSimulations
```

## Overview

`PowerSimulations.jl` is a power system operations simulation tool developed as a flexible and open source software for quasi-static power systems simulations including Production Cost Models. `PowerSimulations.jl` tackles the issues of developing a simulation model in a modular way providing tools for the formulation of decision models and emulation models that can be solved independently or in an interconnected fashion.

`PowerSimulations.jl` supports the workflows to develop simulations by separating the development
of operations models and simulation models.

  - **Operation Models**: Optimization model used to find the solution of an operation problem.
  - **Simulations Models**: Defined the requirements to find solutions to a sequence of operation problems in a way that resembles the procedures followed by operators.

The most common Simulation Model is the solution of a Unit Commitment and Economic Dispatch sequence of problems. This model is used in commercial Production Cost Modeling tools, but it has a limited scope of analysis.

## How the documentation is structured

`PowerSimulations.jl` documentation and code are organized according to the needs of different users depending on their skillset and requirements. In broad terms there are three categories:

  - **Modeler**: Users that want to solve an operations problem or run a simulation using the existing models in `PowerSimulations.jl`. For instance, answer questions about the change in operation costs in future fuel mixes. Check the formulations library page to choose a modeling strategy that fits your needs.

  - **Model Developer**: Users that want to develop custom models and workflows for the simulation of a power system operation. For instance, study the impacts of an stochastic optimization problem over a deterministic.
  - **Code Base Developers**: Users that want to add new core functionalities or fix bugs in the core capabilities of `PowerSimulations.jl`.

`PowerSimulations.jl` is an active project under development, and we welcome your feedback,
suggestions, and bug reports.

**Note**: `PowerSimulations.jl` uses the data model implemented in [`PowerSystems.jl`](https://github.com/NREL-Sienna/PowerSystems.jl)
to construct optimization models. In most cases, you need to add `PowerSystems.jl` to your scripts.

## Installation

The latest stable release of PowerSimulations can be installed using the Julia package manager with

```julia
] add PowerSimulations
```

For the current development version, "checkout" this package with

```julia
] add PowerSimulations#main
```

An appropriate optimization solver is required for running PowerSimulations models. Refer to [`JuMP.jl` solver's page](https://jump.dev/JuMP.jl/stable/installation/#Install-a-solver) to select the most appropriate for the application of interest.

* * *

PowerSystems has been developed as part of the Scalable Integrated Infrastructure Planning
(SIIP) initiative at the U.S. Department of Energy's National Renewable Energy
Laboratory ([NREL](https://www.nrel.gov/)).
