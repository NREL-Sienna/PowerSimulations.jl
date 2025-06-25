# [Structure of Operation Problem Models](@id operation_problem_models)

In most cases operation problem models are optimization models. Although in `PowerSimulations.jl` it is
possible to define arbitrary problems that can reflect heuristic decision rules, this is not the common case. This page focuses on explaining the structure of operations problems that employ an optimization problem and solver.

The first aspect to consider when thinking about developing a model compatible with `PowerSimulations.jl` is that although we support all of `JuMP.jl` objects, you need to employ [anonymous constraints and variables in JuMP](https://jump.dev/JuMP.jl/stable/manual/variables/#anonymous_variables)
and register the constraints, variables and other optimization objects into PowerSimulations.jl's optimization container. Otherwise the features to use your problem in the simulation like the coordination with other problems and post processing won't work.

!!! info
    
    The requirements for the simulation of Power Systems operations are more strict than solving an optimization problem once with just `JuMP.jl`. The requirements imposed by `PowerSimulations.jl` to integrate your models in a simulation are designed to help with other complex operations that go beyond `JuMP.jl` scope.
