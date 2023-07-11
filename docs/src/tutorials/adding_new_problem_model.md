# Adding an Operations Problem Model

This tutorial will show how to create a custom decision problem model. These cases are the ones
where the user want to solve a fully specified problem. Some examples of custom decision models include:

- Solving a custom Security Constrained Unit Commitment Problem
- Solving a market agent utility maximization Problem. See examples of this functionality in HybridSystemsSimulations.jl

The tutorial follows the usual steps for operational model building. First, build the decision model in isolation and second integrate int a simulation. In most cases there will be more than one way of achieving
the same objective when it comes to implementing the model. This guide shows a general set of steps and requirements but it is by no means an exhaustive and detailed guide on developing custom decision models.

!!! warning
    All the code in this tutorial is considered "pseudo-code". If you copy-paste will likely not work out of the box. You need to develop the internals of the functions correctly for the examples below to work.

## General Rules

1. As a general rule you need to understand Julia's terminology such as multiple dispatch, parametried structs and method overloading among others. Developing custom models for an operational simulation is highly technical task and requires skilled development. This tuturial also requires good understanding of PowerSystems.jl data structures and features which are covered in the tutorials section of PowerSystems.jl documentation.
Finally, developing a custom model decision model that will employ an optimization model under the hood requires understanding JuMP.jl.

2. Need to employ [anonymous constraints and variables in JuMP](https://jump.dev/JuMP.jl/stable/manual/variables/#anonymous_variables)
and register the constraints, variables and other optimization objects into PowerSimulations.jl's optimization container. Otherwise the
features to use your problem in the simulation like the coordination with other problems and post processing won't work. More on this in the section [How to develop your `build_model!` function](@ref) below.

3. Overload the required methods for your custom decision models. In some cases it will be possible to re-use some of the other methods that exist in PowerSimulations to make life easier for variable addition and constraint creation but this is not required.

## Decision Problem

### Step 1: Define a Custom Decision Problem

Define a decision problem struct as a subtype of `PowerSimulations.DecisionProblem`. This requirement will enable a lot of the underlying functionality that relies on multiple dispatch. DecisionProblems are used to parameterize the behavior of `DecisionModel` objects which are just containers
for the parameters, references and the optimization problem.

It is possible to define a Custom Decision Problem that gives the user full control over the build, solve and execution process since it imposes less requirements on the developer. However, with less requirements there are also less check and validations performed inside of PowerSimulations which might lead to unexpected erros.

```julia
struct MyCustomDecisionProblem <: PSI.DecisionProblem end
```

Alternatevely, it is possible to define a Custom Decision Problem subtyping from `DefaultDecisionProblem` which imposes more requirements and structure onto the developer but employs more checks and validations in the process. Be aware that this route will decrease the flexibility of what can be done inside the custom model.

```julia
struct MyCustomDecisionProblem <: PSI.DefaultDecisionProblem end
```

Once the problem type is defined, initialize the decision model container with your custom decision problem passing the solver and some of the settings you need for the solution of the problem. For custom problems some of the settings need manual implementation by the developer. Settings availability is also dependent on wether  you choose to subtype from `PSI.DecisionProblem` or `PSI.DefaultDecisionProblem`

```julia
my_model = DecisionModel{MyCustomDecisionProblem}(
    sys;
    name = "MyModel",
    optimizer = optimizer_with_attributes(HiGHS.Optimizer),
     optimizer_solve_log_print = true,
)
```

#### Mandatory Method Overloads

1. `build_model!`: This method build the `JuMP` optimization model.

#### Optional Method Overloads

These methods can be defined optionally for your problem. By default for problems subtyped from `DecisionProblem` these checks are not executed. If the problems are subtyped from `DefaultDecisionProblem` these checks are always conducted with PowerSimulations defaults and require compliance with those defaults to pass. In any case, these can be overloaded when necessary depending on the problem requirements.

1. `validate_template`
2. `validate_time_series`
3. `reset!`
4. `solve_impl!`

### How to develop your `build_model!` function



```julia
function PSI.build_model!(model::PSI.DecisionModel{MyCustomDecisionProblem})
    container = PSI.get_optimization_container(model)
    PSI.set_time_steps!(container, 1:24) # <- Mandatory
    system = PSI.get_system(model)



    update_objective_function!(container) # <- Mandatory
end
```

## Emulation Problem
