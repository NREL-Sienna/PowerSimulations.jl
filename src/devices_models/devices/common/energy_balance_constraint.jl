@doc raw"""
Constructs multi-timestep constraint from initial condition, efficiency data, and variable tuple

# Constraints

If t = 1:

``` varenergy[name, 1] == initial_conditions[ix].value + varin[name, 1]*eff_in*fraction_of_hour - varout[name, 1]*fraction_of_hour/eff_out ```

If t > 1:

``` varenergy[name, t] == varenergy[name, t-1] + varin[name, t]*eff_in*fraction_of_hour - varout[name, t]*fraction_of_hour/eff_out ```

# LaTeX

`` x^{energy}_1 == x^{energy}_{init} + frhr \eta^{in} x^{in}_1 - \frac{frhr}{\eta^{out}} x^{out}_1, \text{ for } t = 1 ``

`` x^{energy}_t == x^{energy}_{t-1} + frhr \eta^{in} x^{in}_t - \frac{frhr}{\eta^{out}} x^{out}_t, \forall t \geq 2 ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varenergy'
* efficiency_data::Tuple{Vector{String}, Vector{InOut}} :: charging/discharging efficiencies
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : varin
- : var_names[2] : varout
- : var_names[3] : varenergy

"""
function energy_balance(
    psi_container::PSIContainer,
    initial_conditions::Vector{InitialCondition},
    efficiency_data::Tuple{Vector{String}, Vector{InOut}},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    parameters = model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    name_index = efficiency_data[1]

    varin = get_variable(psi_container, var_names[1])
    varout = get_variable(psi_container, var_names[2])
    varenergy = get_variable(psi_container, var_names[3])

    constraint = add_cons_container!(psi_container, cons_name, name_index, time_steps)

    for (ix, name) in enumerate(name_index)
        eff_in = efficiency_data[2][ix].in
        eff_out = efficiency_data[2][ix].out
        # Create the PGAE outside of the constraint definition
        balance =
            initial_conditions[ix].value + varin[name, 1] * eff_in * fraction_of_hour -
            (varout[name, 1]) * fraction_of_hour / eff_out
        constraint[name, 1] =
            JuMP.@constraint(psi_container.JuMPmodel, varenergy[name, 1] == balance)
    end

    for t in time_steps[2:end], (ix, name) in enumerate(name_index)
        eff_in = efficiency_data[2][ix].in
        eff_out = efficiency_data[2][ix].out

        constraint[name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, t] ==
            varenergy[name, t - 1] + varin[name, t] * eff_in * fraction_of_hour -
            (varout[name, t]) * fraction_of_hour / eff_out
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
* param_reference::UpdateRef : UpdateRef to access the inflow parameter
"""
function energy_balance_hydro_param!(
    psi_container::PSIContainer,
    initial_conditions::Vector{InitialCondition},
    time_series_data::Tuple{
        Vector{DeviceTimeSeriesConstraintInfo},
        Vector{DeviceTimeSeriesConstraintInfo},
    },
    cons_names::Tuple{Symbol, Symbol},
    var_names::Tuple{Symbol, Symbol, Symbol},
    param_references::Tuple{UpdateRef, UpdateRef},
)
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    fraction_of_hour = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR

    inflow_data = time_series_data[1]
    target_data = time_series_data[2]

    name_index = [get_component_name(d) for d in inflow_data]

    varspill = get_variable(psi_container, var_names[1])
    varout = get_variable(psi_container, var_names[2])
    varenergy = get_variable(psi_container, var_names[3])

    balance_cons_name = cons_names[1]
    target_cons_name = cons_names[2]
    balance_param_reference = param_references[1]
    target_param_reference = param_references[2]

    container_inflow =
        add_param_container!(psi_container, balance_param_reference, name_index, time_steps)
    param_inflow = get_parameter_array(container_inflow)
    multiplier_inflow = get_multiplier_array(container_inflow)
    container_target =
        add_param_container!(psi_container, target_param_reference, name_index, time_steps)
    param_target = get_parameter_array(container_target)
    multiplier_target = get_multiplier_array(container_target)

    balance_constraint =
        add_cons_container!(psi_container, balance_cons_name, name_index, time_steps)
    target_constraint = add_cons_container!(psi_container, target_cons_name, name_index, 1)

    for (ix, d) in enumerate(inflow_data)
        name = get_component_name(d)
        multiplier_inflow[name, 1] = d.multiplier
        param_inflow[name, 1] = PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[1])
        exp =
            initial_conditions[ix].value +
            (
                multiplier_inflow[name, 1] * param_inflow[name, 1] - varspill[name, 1] -
                varout[name, 1]
            ) * fraction_of_hour
        balance_constraint[name, 1] =
            JuMP.@constraint(psi_container.JuMPmodel, varenergy[name, 1] == exp)

        for t in time_steps[2:end]
            param_inflow[name, t] =
                PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[t])
            exp =
                varenergy[name, t - 1] +
                (
                    d.multiplier * param_inflow[name, t] - varspill[name, t] -
                    varout[name, t]
                ) * fraction_of_hour
            balance_constraint[name, t] =
                JuMP.@constraint(psi_container.JuMPmodel, varenergy[name, t] == exp)
        end
    end

    for (ix, d) in enumerate(target_data)
        name = get_component_name(d)
        for t in time_steps
            param_target[name, t] =
                PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[t])
        end
        target_constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, time_steps[end]] >=
            d.multiplier * param_target[name, time_steps[end]]
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
function energy_balance_hydro!(
    psi_container::PSIContainer,
    initial_conditions::Vector{InitialCondition},
    time_series_data::Tuple{
        Vector{DeviceTimeSeriesConstraintInfo},
        Vector{DeviceTimeSeriesConstraintInfo},
    },
    cons_names::Tuple{Symbol, Symbol},
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR

    inflow_data = time_series_data[1]
    target_data = time_series_data[2]

    name_index = [get_component_name(d) for d in inflow_data]

    varspill = get_variable(psi_container, var_names[1])
    varout = get_variable(psi_container, var_names[2])
    varenergy = get_variable(psi_container, var_names[3])

    balance_cons_name = cons_names[1]
    target_cons_name = cons_names[2]

    balance_constraint =
        add_cons_container!(psi_container, balance_cons_name, name_index, time_steps)
    target_constraint = add_cons_container!(psi_container, target_cons_name, name_index, 1)

    for (ix, d) in enumerate(inflow_data)
        name = get_component_name(d)
        balance_constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, 1] ==
            initial_conditions[ix].value +
            (d.multiplier * d.timeseries[1] - varspill[name, 1] - varout[name, 1]) *
            fraction_of_hour
        )

        for t in time_steps[2:end]
            balance_constraint[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                varenergy[name, t] ==
                varenergy[name, t - 1] +
                (d.multiplier * d.timeseries[t] - varspill[name, t] - varout[name, t]) *
                fraction_of_hour
            )
        end
    end

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
Constructs multi-timestep constraint from initial condition, efficiency data, and variable tuple for pumped hydro
# Constraints
If t = 1:
``` varenergy_up[name, 1] == initial_conditions[ix].value + (param_inflow[name, t] + varin[name, 1] - varspill[name, 1] - varout[name, 1])*fraction_of_hour ```
If t > 1:
``` varenergy_up[name, t] == varenergy_up[name, t-1] + (param_inflow[name, t] + varin[name, t] - varspill[name, t] - varout[name, t])*fraction_of_hour ```
# LaTeX
`` x^{energy}_1 == x^{energy}_{init} + frhr  (x^{in}_1 + x^{in}_1 - x^{spillage}_1 -  x^{out}_1), \text{ for } t = 1 ``
`` x^{energy}_t == x^{energy}_{t-1} + frhr (x^{in}_t + x^{in}_t - x^{spillage}_t - x^{out}_t), \forall t \geq 2 ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varenergy_up'
* inflow_data::Vector{DeviceTimeSeriesConstraintInfo} :: Inflow energy forecast information
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : varspill
- : var_names[2] : varout
- : var_names[3] : varenergy_up
- : var_names[4] : varin
* param_reference::UpdateRef : UpdateRef to access the inflow parameter
"""
function energy_balance_hydro_param!(
    psi_container::PSIContainer,
    initial_conditions::Vector{InitialCondition},
    ts_data::Tuple{
        Vector{DeviceTimeSeriesConstraintInfo},
        Vector{DeviceTimeSeriesConstraintInfo},
    },
    cons_name::Tuple{Symbol, Symbol},
    var_names::Tuple{Symbol, Symbol, Symbol, Symbol, Symbol},
    param_reference::Tuple{UpdateRef, UpdateRef},
)
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    fraction_of_hour = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    inflow_data = ts_data[1]
    outflow_data = ts_data[2]
    inflow_name_index = [get_component_name(d) for d in inflow_data]
    outflow_name_index = [get_component_name(d) for d in outflow_data]

    varspill = get_variable(psi_container, var_names[1])
    varout = get_variable(psi_container, var_names[2])
    varenergy_up = get_variable(psi_container, var_names[3])
    varin = get_variable(psi_container, var_names[4])
    varenergy_down = get_variable(psi_container, var_names[5])

    container_inflow = add_param_container!(
        psi_container,
        param_reference[1],
        inflow_name_index,
        time_steps,
    )
    param_inflow = get_parameter_array(container_inflow)
    multiplier_inflow = get_multiplier_array(container_inflow)
    container_outflow = add_param_container!(
        psi_container,
        param_reference[2],
        outflow_name_index,
        time_steps,
    )
    param_outflow = get_parameter_array(container_outflow)
    multiplier_outflow = get_multiplier_array(container_outflow)
    constraint_up =
        add_cons_container!(psi_container, cons_name[1], inflow_name_index, time_steps)
    constraint_down =
        add_cons_container!(psi_container, cons_name[2], outflow_name_index, time_steps)

    for (ix, d) in enumerate(inflow_data)
        name = get_component_name(d)
        pump_eff = 1.0 # TODO: get pump efficiency PSY.get_pump_efficiency(d)
        multiplier_inflow[name, 1] = d.multiplier
        param_inflow[name, 1] = PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[1])
        exp =
            initial_conditions[ix].value +
            (
                multiplier_inflow[name, 1] * param_inflow[name, 1] +
                varin[name, 1] * pump_eff - varspill[name, 1] - varout[name, 1]
            ) * fraction_of_hour
        constraint_up[name, 1] =
            JuMP.@constraint(psi_container.JuMPmodel, varenergy_up[name, 1] == exp)

        for t in time_steps[2:end]
            param_inflow[name, t] =
                PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[t])
            exp =
                varenergy_up[name, t - 1] +
                (
                    d.multiplier * param_inflow[name, t] + varin[name, t] * pump_eff -
                    varspill[name, t] - varout[name, t]
                ) * fraction_of_hour
            constraint_up[name, t] =
                JuMP.@constraint(psi_container.JuMPmodel, varenergy_up[name, t] == exp)
        end
    end

    for (ix, d) in enumerate(outflow_data)
        name = get_component_name(d)
        pump_eff = 1.0 # TODO: get pump efficiency PSY.get_pump_efficiency(d)
        multiplier_outflow[name, 1] = d.multiplier
        param_outflow[name, 1] = PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[1])
        exp =
            initial_conditions[ix].value +
            (
                varspill[name, 1] + varout[name, 1] -
                multiplier_outflow[name, 1] * param_outflow[name, 1] -
                varin[name, 1] * pump_eff
            ) * fraction_of_hour
        constraint_down[name, 1] =
            JuMP.@constraint(psi_container.JuMPmodel, varenergy_down[name, 1] == exp)

        for t in time_steps[2:end]
            param_outflow[name, t] =
                PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[t])
            exp =
                varenergy_down[name, t - 1] +
                (
                    varspill[name, t] + varout[name, t] -
                    d.multiplier * param_outflow[name, t] - varin[name, t] * pump_eff
                ) * fraction_of_hour
            constraint_down[name, t] =
                JuMP.@constraint(psi_container.JuMPmodel, varenergy_down[name, t] == exp)
        end
    end

    return
end

@doc raw"""
Constructs multi-timestep constraint from initial condition, efficiency data, and variable tuple for pumped hydro
# Constraints
If t = 1:
``` varenergy[name, 1] == initial_conditions[ix].value + (paraminflow[name, t] + varin[name, 1] - varspill[name, 1] - varout[name, 1])*fraction_of_hour ```
If t > 1:
``` varenergy[name, t] == varenergy[name, t-1] + (paraminflow[name, t] + varin[name, t] - varspill[name, t] - varout[name, t])*fraction_of_hour ```
# LaTeX
`` x^{energy}_1 == x^{energy}_{init} + frhr  (x^{in}_1 + x^{in}_1 - x^{spillage}_1 -  x^{out}_1), \text{ for } t = 1 ``
`` x^{energy}_t == x^{energy}_{t-1} + frhr (x^{in}_t + x^{in}_t - x^{spillage}_t - x^{out}_t), \forall t \geq 2 ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varenergy'
* inflow_data::TVector{DeviceTimeSeriesConstraintInfo} :: Inflow energy forecast information
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : varspill
- : var_names[2] : varout
- : var_names[3] : varenergy
- : var_names[4] : varin
"""
function energy_balance_hydro!(
    psi_container::PSIContainer,
    initial_conditions::Vector{InitialCondition},
    ts_data::Tuple{
        Vector{DeviceTimeSeriesConstraintInfo},
        Vector{DeviceTimeSeriesConstraintInfo},
    },
    cons_name::Tuple{Symbol, Symbol},
    var_names::Tuple{Symbol, Symbol, Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    inflow_data = ts_data[1]
    outflow_data = ts_data[2]
    inflow_name_index = [get_component_name(d) for d in inflow_data]
    outflow_name_index = [get_component_name(d) for d in outflow_data]

    varspill = get_variable(psi_container, var_names[1])
    varout = get_variable(psi_container, var_names[2])
    varenergy_up = get_variable(psi_container, var_names[3])
    varin = get_variable(psi_container, var_names[4])
    varenergy_down = get_variable(psi_container, var_names[5])

    constraint_up =
        add_cons_container!(psi_container, cons_name[1], inflow_name_index, time_steps)
    constraint_down =
        add_cons_container!(psi_container, cons_name[2], outflow_name_index, time_steps)

    for (ix, d) in enumerate(inflow_data)
        name = get_component_name(d)
        pump_eff = 1.0 # TODO: get pump efficiency PSY.get_pump_efficiency(d)
        constraint_up[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy_up[name, 1] ==
            initial_conditions[ix].value +
            (
                d.multiplier * d.timeseries[1] + varin[name, 1] * pump_eff -
                varspill[name, 1] - varout[name, 1]
            ) * fraction_of_hour
        )

        for t in time_steps[2:end]
            constraint_up[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                varenergy_up[name, t] ==
                varenergy_up[name, t - 1] +
                (
                    d.multiplier * d.timeseries[t] + varin[name, t] * pump_eff -
                    varspill[name, t] - varout[name, t]
                ) * fraction_of_hour
            )
        end
    end

    for (ix, d) in enumerate(outflow_data)
        name = get_component_name(d)
        pump_eff = 1.0 # TODO: get pump efficiency PSY.get_pump_efficiency(d)
        constraint_down[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy_down[name, 1] ==
            initial_conditions[ix].value +
            (
                varspill[name, 1] + varout[name, 1] - d.multiplier * d.timeseries[1] -
                varin[name, 1] * pump_eff
            ) * fraction_of_hour
        )

        for t in time_steps[2:end]
            constraint_down[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                varenergy_down[name, t] ==
                varenergy_down[name, t - 1] +
                (
                    varspill[name, t] + varout[name, t] - d.multiplier * d.timeseries[t] - varin[name, t] * pump_eff
                ) * fraction_of_hour
            )
        end
    end
    return
end
