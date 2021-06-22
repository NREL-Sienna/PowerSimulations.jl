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
    cons_type::ConstraintType,
    var_types::Tuple{VariableType, VariableType, VariableType},
    ::Type{U},
) where {T <: DeviceTimeSeriesConstraintInfo, U <: PSY.Component}
    time_steps = model_time_steps(optimization_container)
    name_index = [get_component_name(d) for d in target_data]
    varenergy = get_variable(optimization_container, var_types[1], U)
    varslack_up = get_variable(optimization_container, var_types[2], U)
    varslack_dn = get_variable(optimization_container, var_types[3], U)

    target_constraint =
        add_cons_container!(optimization_container, cons_type, U, name_index, time_steps)

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
* parameter::TimeSeriesParameter : TimeSeriesParameter for the RHS
"""
# TODO DT: fix all docstrings that are now invalid
function energy_target_param!(
    optimization_container::OptimizationContainer,
    target_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_type::ConstraintType,
    # TODO: This should be done with AuxVariables
    var_types::Tuple{VariableType, VariableType, VariableType},
    parameter::TimeSeriesParameter,
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = model_time_steps(optimization_container)
    name_index = [get_component_name(d) for d in target_data]
    varenergy = get_variable(optimization_container, var_types[1], T)
    varslack_up = get_variable(optimization_container, var_types[2], T)
    varslack_dn = get_variable(optimization_container, var_types[3], T)

    container_target = add_param_container!(
        optimization_container,
        parameter,
        T,
        name_index,
        time_steps,
    )
    param_target = get_parameter_array(container_target)
    multiplier_target = get_multiplier_array(container_target)
    target_constraint =
        add_cons_container!(optimization_container, cons_type, T, name_index, time_steps)

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
