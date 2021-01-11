@doc raw"""
Constructs constraint energy target data, and variable
# Constraints
`` varenergy[name, end] >= paramenergytarget[name, end] ``
# LaTeX
`` x^{energy}_t >= x^{energy}_{target} \text{ for } t = end ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* constriant_data::Vector{DeviceTimeSeriesConstraintInfo}: Target energy storage information
* cons_name::Symbol : energy target constraint name
* var_name::Symbol : the name of the energy variable
* param_reference::UpdateRef : UpdateRef to access the inflow parameter
"""
function energy_target_timeseries_param(
    psi_container::PSIContainer,
    constriant_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    var_name::Symbol,
    param_references::UpdateRef,
)
    time_steps = model_time_steps(psi_container)
    name_index = (d.component_name for d in constriant_data)
    varenergy = get_variable(psi_container, var_name)
    target_param_reference = param_references

    container_target =
        add_param_container!(psi_container, target_param_reference, name_index, 1)
    param_target = get_parameter_array(container_target)
    multiplier_target = get_multiplier_array(container_target)
    target_constraint = add_cons_container!(psi_container, cons_name, name_index, 1)

    for d in enumerate(constriant_data), name in get_component_name(d)
        multiplier_target[name, 1] = d.multiplier
        param_target[name, 1] =
            PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[time_steps[end]])

        target_constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, time_steps[end]] >=
            multiplier_target[name, 1] * param_target[name, 1]
        )
    end

    return
end

@doc raw"""
Constructs constraint energy target data, and variable
# Constraints
`` varenergy[name, end] >= paramenergytarget[name, end] ``
# LaTeX
`` x^{energy}_t >= x^{energy}_{target} \text{ for } t = end ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* constriant_data::Vector{DeviceTimeSeriesConstraintInfo}: Target energy storage information
* cons_name::Symbol : energy target constraint name
* var_name::Symbol : the name of the energy variable
* param_reference::UpdateRef : UpdateRef to access the inflow parameter
"""
function energy_target_timeseries(
    psi_container::PSIContainer,
    constriant_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    name_index = (d.component_name for d in constriant_data)
    varenergy = get_variable(psi_container, var_name)

    target_constraint = add_cons_container!(psi_container, cons_name, name_index, 1)

    for d in enumerate(constriant_data), name in get_component_name(d)
        target_constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, time_steps[end]] >=
            d.multiplier * d.timeseries[time_steps[end]]
        )
    end

    return
end

@doc raw"""
Constructs constraint energy target data, and variable
# Constraints
`` varenergy[name, end] >= paramenergytarget[name, end] ``
# LaTeX
`` x^{energy}_t >= x^{energy}_{target} \text{ for } t = end ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* constriant_data::Vector{DeviceTimeSeriesConstraintInfo}: Target energy storage information
* cons_name::Symbol : energy target constraint name
* var_name::Symbol : the name of the energy variable
"""
function energy_target(
    psi_container::PSIContainer,
    constriant_data::Vector{DeviceEnergyTargetConstraintInfo},
    cons_name::Symbol,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    name_index = (d.component_name for d in constriant_data)
    varenergy = get_variable(psi_container, var_name)

    target_constraint = add_cons_container!(psi_container, cons_name, name_index, 1)

    for data in enumerate(constriant_data)
        name = data.component_name
        target_constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, time_steps[end]] >= data.multiplier * data.storage_target
        )
    end

    return
end

@doc raw"""
Constructs constraint energy target data, and variable
# Constraints
`` varenergy[name, end] + varslack[name, end] >= paramenergytarget[name, end] ``
# LaTeX
`` x^{energy}_t + x^{slack}_t >= x^{energy}_{target} \text{ for } t = end ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* constriant_data::Vector{DeviceTimeSeriesConstraintInfo}: Target energy storage information
* cons_name::Symbol : energy target constraint name
* var_names::Symbol : the names of the variables
- : var_names[1] : varenergy
- : var_names[2] : varslack
* param_reference::UpdateRef : UpdateRef to access the inflow parameter
"""
function energy_soft_target_timeseries_param(
    psi_container::PSIContainer,
    constriant_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol},
    param_references::UpdateRef,
)
    time_steps = model_time_steps(psi_container)
    name_index = (d.component_name for d in constriant_data)

    varenergy = get_variable(psi_container, var_names[1])
    varslack = get_variable(psi_container, var_names[2])

    target_param_reference = param_references

    container_target =
        add_param_container!(psi_container, target_param_reference, name_index, time_steps)
    param_target = get_parameter_array(container_target)
    multiplier_target = get_multiplier_array(container_target)

    target_constraint = add_cons_container!(psi_container, cons_name, name_index, 1)

    for d in enumerate(constriant_data)
        name = get_component_name(d)
        multiplier_target[name, 1] = d.multiplier
        param_target[name, 1] =
            PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[time_steps[end]])

        target_constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, time_steps[end]] + varslack[name, time_steps[end]] >=
            multiplier_target[name, 1] * param_target[name, 1]
        )
    end

    return
end

@doc raw"""
Constructs constraint energy target data, and variable
# Constraints
`` varenergy[name, end] + varslack[name, end] >= paramenergytarget[name, end] ``
# LaTeX
`` x^{energy}_t + x^{slack}_t >= x^{energy}_{target} \text{ for } t = end ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* constriant_data::Vector{DeviceTimeSeriesConstraintInfo}: Target energy storage information
* cons_name::Symbol : energy target constraint name
* var_names::Symbol : the names of the variables
- : var_names[1] : varenergy
- : var_names[2] : varslack
* param_reference::UpdateRef : UpdateRef to access the inflow parameter
"""
function energy_soft_target_timeseries(
    psi_container::PSIContainer,
    constriant_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    name_index = (d.component_name for d in constriant_data)

    varenergy = get_variable(psi_container, var_names[1])
    varslack = get_variable(psi_container, var_names[2])

    target_constraint = add_cons_container!(psi_container, cons_name, name_index, 1)

    for d in enumerate(constriant_data)
        name = get_component_name(d)

        target_constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, time_steps[end]] + varslack[name, time_steps[end]] >=
            d.multiplier * d.timeseries[time_steps[end]]
        )
    end

    return
end

@doc raw"""
Constructs constraint energy target data, and variable
# Constraints
`` varenergy[name, end] + varslack[name, end] >= paramenergytarget[name, end] ``
# LaTeX
`` x^{energy}_t + x^{slack}_t >= x^{energy}_{target} \text{ for } t = end ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* constriant_data::Vector{DeviceEnergyTargetConstraintInfo}: Target energy storage information
* cons_name::Symbol : energy target constraint name
* var_names::Symbol : the names of the variables
- : var_names[1] : varenergy
- : var_names[2] : varslack
"""
function energy_soft_target(
    psi_container::PSIContainer,
    constriant_data::Vector{DeviceEnergyTargetConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    name_index = (d.component_name for d in constriant_data)

    varenergy = get_variable(psi_container, var_names[1])
    varslack = get_variable(psi_container, var_names[2])

    target_constraint = add_cons_container!(psi_container, cons_name, name_index, 1)

    for data in enumerate(constriant_data)
        name = data.component_name
        target_constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, time_steps[end]] + varslack[name, time_steps[end]] >=
            data.multiplier * data.storage_target
        )
    end

    return
end
