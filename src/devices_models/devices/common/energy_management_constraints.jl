@doc raw"""
Constructs constraint energy target data, and variable
# Constraints
`` varenergy[name, end]  >= paramenergytarget[name, end] ``
# LaTeX
`` x^{energy}_t  >= x^{energy}_{target} \text{ for } t = end ``
# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* time_series_data::Vector{DeviceTimeSeriesConstraintInfo} : Target reservoir storage forecast information
* cons_name::Symbol : energy target constraint name
* var_key::VariableKey : the name of the Energy  variable
"""
function energy_target!(
    optimization_container::OptimizationContainer,
    target_data::Vector{T},
    cons_name::Symbol,
    var_keys::Tuple{VariableKey, VariableKey, VariableKey},
) where {T <: DeviceTimeSeriesConstraintInfo}
    time_steps = model_time_steps(optimization_container)
    name_index = [get_component_name(d) for d in target_data]
    varenergy = get_variable(optimization_container, var_keys[1])
    varslack_up = get_variable(optimization_container, var_keys[2])
    varslack_dn = get_variable(optimization_container, var_keys[3])

    target_constraint =
        add_cons_container!(optimization_container, cons_name, name_index, time_steps)

    for data in target_data, t in time_steps
        name = get_component_name(data)
        target_constraint[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy[name, t] + varslack_up[name, t] + varslack_dn[name, t] ==
            data.multiplier * data.timeseries[t]
        )
    end

    return
end

@doc raw"""
Constructs constraint energy target data, and variable
# Constraints
`` varenergy[name, end]  >= paramenergytarget[name, end] ``
# LaTeX
`` x^{energy}_t  >= x^{energy}_{target} \text{ for } t = end ``
# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* time_series_data::Vector{DeviceTimeSeriesConstraintInfo} : Target reservoir storage forecast information
* cons_names::Symbol : name of the constraint
* var_names::Symbol : the name of the energy variable
* param_reference::UpdateRef : UpdateRef to access the target parameter
"""
function energy_target_param!(
    optimization_container::OptimizationContainer,
    target_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    var_keys::Tuple{VariableKey, VariableKey, VariableKey},
    param_reference::UpdateRef,
)
    time_steps = model_time_steps(optimization_container)
    name_index = [get_component_name(d) for d in target_data]
    varenergy = get_variable(optimization_container, var_keys[1])
    varslack_up = get_variable(optimization_container, var_keys[2])
    varslack_dn = get_variable(optimization_container, var_keys[3])

    container_target = add_param_container!(
        optimization_container,
        param_reference,
        name_index,
        time_steps,
    )
    param_target = get_parameter_array(container_target)
    multiplier_target = get_multiplier_array(container_target)
    target_constraint =
        add_cons_container!(optimization_container, cons_name, name_index, time_steps)

    for d in target_data, t in time_steps
        name = get_component_name(d)
        param_target[name, t] =
            PJ.add_parameter(optimization_container.JuMPmodel, d.timeseries[t])
        multiplier_target[name, t] = d.multiplier
        target_constraint[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy[name, t] + varslack_up[name, t] + varslack_dn[name, t] ==
            multiplier_target[name, t] * param_target[name, t]
        )
    end

    return
end
