# PowerSimulations

This repository is meant to host a set of tools to perform energy systems analysis, mainly electric power systems in a modular fashion. It contains different models and approaches to find a solution. 

These tools have different objectives: 

- Provide a flexible modeling framework that can accomodate problems of different complexity and at different time-scales.

- Construct large scale optimization problems in an easier way and avoid repetition of work when addind complexity to the modeling. 

- Exploit Julia's capabilities enable the solution of difficult problems with increased the computational performance.  

## Installation

This package is not yet registered. **Until it is, things may change. It is perfectly
usable but should not be considered stable**.

You can install it by typing

```julia
julia> Pkg.clone("https://github.com/NREL/PowerSimulations.jl")
```
## Usage

Once installed, the `PowerSimulations` package can by used by typing

```julia
using PSModelsv2
```

- ed_models: Contains models and modifiers for the [Economic Distpatch (ED) Problem](https://en.wikipedia.org/wiki/Economic_dispatch). 

- expansion_models: Contains models for the power system expansion problem. Most of the models are based on the book [Investment in Electricity Generation and Transmission](http://www.springer.com/gp/book/9783319294995). 

- uc_models: [Unit Commitment Models](https://en.wikipedia.org/wiki/Unit_commitment_problem_in_electrical_power_production)

- Notebooks: Jupyter notebooks with detailed description and example code for the different models in MEMFS. Also contains some notebooks that explore advanced concepts in renewable energy integration. 


