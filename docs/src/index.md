# PowerSimulations.jl

```@meta
CurrentModule = PowerSimulations
```

## About

`PowerSimulations.jl` is part of the National Renewable Energy Laboratory's
[Sienna ecosystem](https://www.nrel.gov/analysis/sienna.html), an open source framework for
scheduling problems and dynamic simulations for power systems. The Sienna ecosystem can be
[found on github](https://github.com/NREL-Sienna/Sienna). It contains three applications:

  - [Sienna\Data](https://github.com/NREL-Sienna/Sienna?tab=readme-ov-file#siennadata) enables
    efficient data input, analysis, and transformation
  - [Sienna\Ops](https://github.com/NREL-Sienna/Sienna?tab=readme-ov-file#siennaops) enables
    enables system scheduling simulations by formulating and solving optimization problems
  - [Sienna\Dyn](https://github.com/NREL-Sienna/Sienna?tab=readme-ov-file#siennadyn) enables
    system transient analysis including small signal stability and full system dynamic
    simulations

Each application uses multiple packages in the [`Julia`](http://www.julialang.org)
programming language.

`PowerSimulations.jl` is a power system operations simulation tool developed as a flexible and open source software for quasi-static power systems simulations including Production Cost Models. `PowerSimulations.jl` tackles the issues of developing a simulation model in a modular way providing tools for the formulation of decision models and emulation models that can be solved independently or in an interconnected fashion.

`PowerSimulations.jl` supports the workflows to develop simulations by separating the development
of operations models and simulation models.

  - **Operation Models**: Optimization model used to find the solution of an operation problem.
  - **Simulations Models**: Defined the requirements to find solutions to a sequence of operation problems in a way that resembles the procedures followed by operators.

The most common Simulation Model is the solution of a Unit Commitment and Economic Dispatch sequence of problems. This model is used in commercial Production Cost Modeling tools, but it has a limited scope of analysis.

## How To Use This Documentation

There are five main sections containing different information:

  - **Tutorials** - Detailed walk-throughs to help you *learn* how to use
    `PowerSimulations.jl`
  - **How to...** - Directions to help *guide* your work for a particular task
  - **Explanation** - Additional details and background information to help you *understand*
    `PowerSimulations.jl`, its structure, and how it works behind the scenes
  - **Reference** - Technical references and API for a quick *look-up* during your work
  - **Formulation Library** - #TODO

`PowerSimulations.jl` strives to follow the [Diataxis](https://diataxis.fr/) documentation
framework.

## Getting Started

If you are new to `PowerSimulations.jl`, here's how we suggest getting started:

 1. [Install](@ref install)
