# Adding an Operations Problem Model

This tutorial will show how to create a custom decision problem model. These cases are the ones
where the user want to solve a fully specified problem. Some examples of custom decision models include:

  - Solving a custom Security Constrained Unit Commitment Problem
  - Solving a market agent utility maximization Problem. See examples of this functionality in HybridSystemsSimulations.jl

The tutorial follows the usual steps for operational model building. First, build the decision model in isolation and second, integrate it into a simulation. In most cases there will be more than one way of achieving
the same objective when it comes to implementing the model. This guide shows a general set of steps and requirements but it is by no means an exhaustive and detailed guide on developing custom decision models.

!!! warning
    
    All the code in this tutorial is considered "pseudo-code". Copy-paste will likely not work out of the box. You need to develop the internals of the functions correctly for the examples below to work.

## General Rules

 1. As a general rule you need to understand Julia's terminology such as multiple dispatch, parametric structs and method overloading, among others. Developing custom models for an operational simulation is a highly technical task and requires skilled development. This tutorial also requires good understanding of PowerSystems.jl data structures and features which are covered in the tutorials section of PowerSystems.jl documentation.
    Finally, developing a custom model decision model that will employ an optimization model under the hood requires understanding JuMP.jl.

 2. Need to employ [anonymous constraints and variables in JuMP](https://jump.dev/JuMP.jl/stable/manual/variables/#anonymous_variables)
    and register the constraints, variables and other optimization objects into PowerSimulations.jl's optimization container. Otherwise the
    features to use your problem in the simulation like the coordination with other problems and post processing won't work. More on this in the section [How to develop your `build_model!` function](@ref) below.
 3. Implement the required methods for your custom decision models. In some cases it will be possible to re-use some of the other methods that exist in PowerSimulations to make life easier for variable addition and constraint creation but this is not required.

## Decision Problem

### Step 1: Define a Custom Decision Problem

Define a decision problem struct as a subtype of `PowerSimulations.DecisionProblem`. This requirement will enable a lot of the underlying functionality that relies on multiple dispatch. DecisionProblems are used to parameterize the behavior of [`DecisionModel`](@ref) objects which are just containers
for the parameters, references and the optimization problem.

It is possible to define a Custom Decision Problem that gives the user full control over the build, solve and execution process since it imposes less requirements on the developer. However, with less requirements there are also less checks and validations performed inside of PowerSimulations which might lead to unexpected errors

```julia
struct MyCustomDecisionProblem <: PSI.DecisionProblem end
```

Alternatively, it is possible to define a Custom Decision Problem subtyping from `DefaultDecisionProblem` which imposes more requirements and structure onto the developer but employs more checks and validations in the process. Be aware that this route will decrease the flexibility of what can be done inside the custom model.

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

#### Mandatory Method Implementations

 1. `build_model!`: This method build the `JuMP` optimization model.

#### Optional Method Overloads

These methods can be defined optionally for your problem. By default for problems subtyped from `DecisionProblem` these checks are not executed. If the problems are subtyped from `DefaultDecisionProblem` these checks are always conducted with PowerSimulations defaults and require compliance with those defaults to pass. In any case, these can be overloaded when necessary depending on the problem requirements.

 1. `validate_template`
 2. `validate_time_series!`
 3. `reset!`
 4. `solve_impl!`

### How to develop your `build_model!` function

#### Registering a variable in the model

To register a variable in the model, the developer must first allocate the container into the
optimization container and then populate it. For example, it require start the build function as follows:

!!! info
    
    We recommend calling `import PowerSimulations` and defining the constant `CONST PSI = PowerSimulations` to
    make it easier to read the code and determine which package is responsible for defining the functions.

```julia
function PSI.build_model!(model::PSI.DecisionModel{MyCustomDecisionProblem})
    container = PSI.get_optimization_container(model)
    time_steps = 1:24
    PSI.set_time_steps!(container, time_steps)
    system = PSI.get_system(model)

    thermal_gens = PSY.get_components(PSY.ThermalStandard, system)
    thermal_gens_names = PSY.get_name.(thermal_gens)

    # Create the container for the variable
    variable = PSI.add_variable_container!(
        container,
        PSI.ActivePowerVariable(), # <- This variable is defined in PowerSimulations but the user can define their own
        PSY.ThermalGeneration, # <- Device type for the variable. Can be from PSY or custom defined
        thermal_gens_names, # <- First container dimension
        time_steps, # <- Second container dimension
    )

    # Iterate over the devices and time to store the JuMP variables into the container.
    for t in time_steps, d in thermal_gens_names
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(get_jump_model(container))
        # It is possible to use PSY getter functions to retrieve data from the generators
        JuMP.set_upper_bound(variable[name, t], UB_DATA) # <- Optional
        JuMP.set_lower_bound(variable[name, t], LB_DATA) # <- Optional
    end

    # Add More Variables.....

    return
end
```

#### Registering a constraint in the model

A similar pattern is used to add constraints to the model, in this example the field `meta` is used
to avoid creating unnecessary duplicate constraint types. For instance to reflect upper_bound and lower_bound or upwards and downwards constraints. Meta can take any string value except for the `_` character.

```julia
function PSI.build_model!(model::PSI.DecisionModel{MyCustomDecisionProblem})
    container = PSI.get_optimization_container(model)
    time_steps = 1:24
    PSI.set_time_steps!(container, time_steps)
    system = PSI.get_system(model)

    # VARIABLE ADDITION CODE

    # Constraint additions
    con_ub = PSI.add_constraints_container!(
        container,
        PSI.RangeLimitConstraint(), # <- Constraint Type defined by PSI or your own
        PSY.ThermalGeneration, # <- Device type for variable. Can be PSY or custom
        thermal_gens_names, # <- First container dimension
        time_steps; # <- Second container dimension
        meta = "ub", # <- meta allows to reuse a constraint definition for similar constraints. It only requires to be a string
    )

    con_lb = PSI.add_constraints_container!(
        container,
        PSI.RangeLimitConstraint(),
        PSY.ThermalGeneration,
        thermal_gens_names, # <- First container dimension
        time_steps; # <- Second container dimension
        meta = "lb", # <- meta allows to reuse a constraint definition for similar constraints. It only requires to be a string
    )

    # Retrieve a relevant variable from the container if not defined in
    variable = PSI.get_variable(container, PSI.ActivePowerVariable(), PSY.ThermalGeneration)
    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device) # depends on constraint type and formulation type
        con_ub[ci_name, t] =
            JuMP.@constraint(get_jump_model(container), variable[ci_name, t] >= limits.min)
        con_lb[ci_name, t] =
            JuMP.@constraint(get_jump_model(container), variable[ci_name, t] >= limits.min)
    end

    return
end
```
