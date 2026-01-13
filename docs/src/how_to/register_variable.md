# Register a variable in a custom operation model

In most cases, operation problem models are optimization models. Although in `PowerSimulations.jl` it is
possible to define arbitrary problems that can reflect heuristic decision rules, this is not the common case.

The first aspect to consider when thinking about developing a model compatible with `PowerSimulations.jl` is that although we support all of `JuMP.jl` objects, you need to employ [anonymous constraints and variables](https://jump.dev/JuMP.jl/stable/manual/variables/#anonymous_variables) in `JuMP.jl` and register the constraints, variables and other optimization objects into `PowerSimulations.jl`'s optimization container. Otherwise the features to use your problem in the simulation like the coordination with other problems and post processing won't work.

!!! info
    
    The requirements for the simulation of Power Systems operations are more strict than solving an optimization problem once with just `JuMP.jl`. The requirements imposed by `PowerSimulations.jl` to integrate your models in a simulation are designed to help with other complex operations that go beyond `JuMP.jl` scope.

To register a variable in the model, the developer must first allocate the container into the
optimization container and then populate it. For example, it require start the build function as follows:

!!! warning
    
    All the code in this page is considered "pseudo-code". Copy-paste will likely not work out of the box. You need to develop the internals of the functions correctly for the examples below to work.

```julia
using PowerSystems
using PowerSimulations
import PowerSystems as PSY
import PowerSimulations as PSI

function PSI.build_model!(model::PSI.DecisionModel{MyCustomModel})
    container = PSI.get_optimization_container(model)
    PSI.set_time_steps!(container, 1:24)

    # Create the container for the variable
    variable = PSI.add_variable_container!(
        container,
        PSI.ActivePowerVariable(), # <- This variable is defined in PowerSimulations but the user can define their own
        PSY.ThermalGeneration, # <- Device type for the variable. Can be from PSY or custom defined
        devices_names, # <- First container dimension
        time_steps, # <- Second container dimension
    )

    # Iterate over the devices and time to store the JuMP variables into the container.
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(get_jump_model(container))
        # It is possible to use PSY getter functions to retrieve data from the generators
        # Any other variable property can be specified inside this loop.
        JuMP.set_upper_bound(variable[name, t], UB_DATA) # <- Optional
        JuMP.set_lower_bound(variable[name, t], LB_DATA) # <- Optional
    end

    return
end
```
