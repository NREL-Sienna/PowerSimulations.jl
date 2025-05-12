# Temporary Section for Unsorted Documentation Content

This file collects content from the old documentation that is not currently included in the restructured Diátaxis layout. It is meant for tracking purposes only and will not be included in the final updated documentation.

## From: Welcome Page

### How the documentation is structured

`PowerSimulations.jl` documentation and code are organized according to the needs of different users depending on their skillset and requirements. In broad terms there are three categories:

  - **Modeler**: Users that want to solve an operations problem or run a simulation using the existing models in `PowerSimulations.jl`. For instance, answer questions about the change in operation costs in future fuel mixes. Check the formulations library page to choose a modeling strategy that fits your needs.

  - **Model Developer**: Users that want to develop custom models and workflows for the simulation of a power system operation. For instance, study the impacts of an stochastic optimization problem over a deterministic.
  - **Code Base Developers**: Users that want to add new core functionalities or fix bugs in the core capabilities of `PowerSimulations.jl`.

`PowerSimulations.jl` is an active project under development, and we welcome your feedback,
suggestions, and bug reports.

**Note**: `PowerSimulations.jl` uses the data model implemented in [`PowerSystems.jl`](https://github.com/NREL-Sienna/PowerSystems.jl)
to construct optimization models. In most cases, you need to add `PowerSystems.jl` to your scripts.

### Installation

An appropriate optimization solver is required for running PowerSimulations models. Refer to [`JuMP.jl` solver's page](https://jump.dev/JuMP.jl/stable/installation/#Install-a-solver) to select the most appropriate for the application of interest.
