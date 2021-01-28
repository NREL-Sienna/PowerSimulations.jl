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
    name_index = (get_component_name(d) for d in constriant_data)

    varenergy = get_variable(psi_container, var_names[1])
    varslack = get_variable(psi_container, var_names[2])

    target_constraint = add_cons_container!(psi_container, cons_name, name_index, 1)

    for data in constriant_data
        name = get_component_name(data)
        target_constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, time_steps[end]] + varslack[name, time_steps[end]] >=
            data.multiplier * data.storage_target
        )
    end

    return
end

@doc raw"""
Constructs multi-timestep constraint from initial condition, efficiency data, and variable tuple
# Constraints
If t = 1:
`` varenergy[name, 1] == initial_conditions[ix].value + (paraminflow[name, t] - varspill[name, 1] - varout[name, 1])*fraction_of_hour ``
If t > 1:
`` varenergy[name, t] == varenergy[name, t-1] + (paraminflow[name, t] - varspill[name, t] - varout[name, t])*fraction_of_hour ``
`` varenergy[name, end] >= paramenergytarget[name, end]
# LaTeX
`` x^{energy}_1 == x^{energy}_{init} + frhr  (x^{in}_1 - x^{spillage}_1 -  x^{out}_1), \text{ for } t = 1 ``
`` x^{energy}_t == x^{energy}_{t-1} + frhr (x^{in}_t - x^{spillage}_t - x^{out}_t), \forall t \geq 2 ``
`` x^{energy}_t >= x^{energy}_{target} \text{ for } t = end ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varenergy'
* time_series_data::Tuple{Vector{DeviceTimeSeriesConstraintInfo}, Vector{DeviceTimeSeriesConstraintInfo}} : forecast information
- : time_series_data[1] : Inflow energy forecast information
- : time_series_data[2] : Target reservoir storage forecast information
* cons_names::Tuple{Symbol, Symbol} : name of the constraints
- : cons_names[1] : energy balance constraint name
- : cons_names[2] : energy target constraint name
* var_names::Tuple{Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : varspill
- : var_names[2] : varout
- : var_names[3] : varenergy
"""
function energy_target_hydro!(
    psi_container::PSIContainer,
    target_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    name_index = [get_component_name(d) for d in target_data]
    varenergy = get_variable(psi_container, var_name)
    target_cons_name = cons_name

    target_constraint = add_cons_container!(psi_container, target_cons_name, name_index, 1)

    for (ix, d) in enumerate(target_data)
        name = get_component_name(d)
        target_constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, time_steps[end]] >=
            d.multiplier * d.timeseries[time_steps[end]]
        )
    end

    return
end

@doc raw"""
Constructs multi-timestep constraint from initial condition, efficiency data, and variable tuple
# Constraints
If t = 1:
`` varenergy[name, 1] == initial_conditions[ix].value + (paraminflow[name, t] - varspill[name, 1] - varout[name, 1])*fraction_of_hour ``
If t > 1:
`` varenergy[name, t] == varenergy[name, t-1] + (paraminflow[name, t] - varspill[name, t] - varout[name, t])*fraction_of_hour ``
`` varenergy[name, end] >= paramenergytarget[name, end]
# LaTeX
`` x^{energy}_1 == x^{energy}_{init} + frhr  (x^{in}_1 - x^{spillage}_1 -  x^{out}_1), \text{ for } t = 1 ``
`` x^{energy}_t == x^{energy}_{t-1} + frhr (x^{in}_t - x^{spillage}_t - x^{out}_t), \forall t \geq 2 ``
`` x^{energy}_t >= x^{energy}_{target} \text{ for } t = end ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varenergy'
* time_series_data::Vector{DeviceTimeSeriesConstraintInfo} : Target reservoir storage forecast information
* cons_names::Symbol : name of the constraint
* var_names::Symbol : the name of the energy variable
* param_reference::UpdateRef : UpdateRef to access the target parameter
"""
function energy_target_hydro_param!(
    psi_container::PSIContainer,
    target_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    var_name::Symbol,
    param_reference::UpdateRef,
)
    time_steps = model_time_steps(psi_container)
    name_index = [get_component_name(d) for d in target_data]
    varenergy = get_variable(psi_container, var_name)

    container_target =
        add_param_container!(psi_container, param_reference, name_index, time_steps)
    param_target = get_parameter_array(container_target)
    multiplier_target = get_multiplier_array(container_target)
    target_constraint = add_cons_container!(psi_container, cons_name, name_index, 1)

    for (ix, d) in enumerate(target_data)
        name = get_component_name(d)
        for t in time_steps
            param_target[name, t] =
                PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[t])
            multiplier_target[name, t] = d.multiplier
        end
        target_constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, time_steps[end]] >=
            multiplier_target[name, end] * param_target[name, time_steps[end]]
        )
    end

    return
end
