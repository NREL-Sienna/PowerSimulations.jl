@doc raw"""
Constructs multi-timestep constraint from initial conditions and binary variable tuple.

# Constraints

``` varstart + varstop <= 1.0 ```

If t = 1:

``` varon[name, 1] == ic.value + varstart[name, 1] - varstop[name, 1] ```

where ic in initial_condtions.

If t > 1:

``` varon[name, t] == varon[name, t-1] + varstart[name, t] - varstop[name, t] ```

# LaTeX

`` x^{on}_t + x^{off}_t \leq 1.0 \forall t ``

`` x^{on}_1 = x^{on}_{init} + x^{start}_1 - x^{stop}_1, \text{ for } t = 1 ``

`` x^{on}_t = x^{on}_{t-1} + x^{start}_t - x^{stop}_t, \forall t \geq 2 ``


# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varon'
* cons_name::Symbol : name of the constraint
* var_keys::Tuple{VariableKey, VariableKey, VariableKey} : the names of the variables
-  : var_keys[1] : varstart
-  : var_keys[2] : varstop
-  : var_keys[3] : varon
"""
function device_commitment!(
    optimization_container::OptimizationContainer,
    initial_conditions::Vector{InitialCondition},
    cons_type::ConstraintType,
    var_types::Tuple{VariableType, VariableType, VariableType},
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = model_time_steps(optimization_container)
    varstart = get_variable(optimization_container, var_types[1], T)
    varstop = get_variable(optimization_container, var_types[2], T)
    varon = get_variable(optimization_container, var_types[3], T)
    varstart_names = axes(varstart, 1)
    constraint = add_cons_container!(
        optimization_container,
        cons_type,
        T,
        varstart_names,
        time_steps,
    )
    aux_constraint = add_cons_container!(
        optimization_container,
        cons_type,
        T,
        varstart_names,
        time_steps,
        meta = "aux",
    )

    for ic in initial_conditions
        name = PSY.get_name(ic.device)
        constraint[name, 1] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varon[name, 1] == ic.value + varstart[name, 1] - varstop[name, 1]
        )
        aux_constraint[name, 1] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varstart[name, 1] + varstop[name, 1] <= 1.0
        )
    end

    for t in time_steps[2:end], i in initial_conditions
        name = PSY.get_name(i.device)
        constraint[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varon[name, t] == varon[name, t - 1] + varstart[name, t] - varstop[name, t]
        )
        aux_constraint[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varstart[name, t] + varstop[name, t] <= 1.0
        )
    end
    return
end
