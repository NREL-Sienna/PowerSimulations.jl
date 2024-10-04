# [PowerSimulations.jl Modeling Structure](@id psi_structure)

PowerSimulations enables the simulation of a sequence of power systems optimization problems and provides user control over each aspect of the simulation configuration. Specifically:

  - mathematical formulations can be selected for each component with [`DeviceModel`](@ref) and [`ServiceModel`](@ref)
  - a problem can be defined by creating model entries in a [Operations `ProblemTemplate`s](@ref op_problem_template)
  - models ([`DecisionModel`](@ref) or [`EmulationModel`](@ref)) can be built by applying a `ProblemTemplate` to a `System` and can be executed/solved in isolation or as part of a [`Simulation`](@ref)
  - [`Simulation`](@ref)s can be defined and executed by sequencing one or more models and defining how and when data flows between models.

!!! question "What is the difference between a Model and a Problem?"
    
    A "Problem" is an abstract mathematical description of how to represent power system behavior, whereas a "Model" is a concrete representation of a "Problem" applied to a dataset. I.e. once a Problem is populated with data describing all the loads, generators, lines, etc., it becomes a Model.
