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
``` varenergy[name, 1] == initial_conditions[ix].value + (paraminflow[name, t] - varspill[name, 1] - varout[name, 1])*fraction_of_hour ```
If t > 1:
``` varenergy[name, t] == varenergy[name, t-1] + (paraminflow[name, t] - varspill[name, t] - varout[name, t])*fraction_of_hour ```
# LaTeX
`` x^{energy}_1 == x^{energy}_{init} + frhr  (x^{in}_1 - x^{spillage}_1 -  x^{out}_1), \text{ for } t = 1 ``
`` x^{energy}_t == x^{energy}_{t-1} + frhr (x^{in}_t - x^{spillage}_t - x^{out}_t), \forall t \geq 2 ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varenergy'
* inflow_data::Vector{DeviceTimeSeriesConstraintInfo} :: Inflow energy forecast information
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : varspill
- : var_names[2] : varout
- : var_names[3] : varenergy
* param_reference::UpdateRef : UpdateRef to access the inflow parameter
"""
function energy_balance_external_input_param!(
    psi_container::PSIContainer,
    initial_conditions::Vector{InitialCondition},
    inflow_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol},
    param_reference::UpdateRef,
)
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    fraction_of_hour = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    name_index = (get_name(d) for d in inflow_data)

    varspill = get_variable(psi_container, var_names[1])
    varout = get_variable(psi_container, var_names[2])
    varenergy = get_variable(psi_container, var_names[3])
    container = add_param_container!(psi_container, param_reference, name_index, time_steps)
    paraminflow = get_parameter_array(container)
    multiplier = get_multiplier_array(container)
    constraint = add_cons_container!(psi_container, cons_name, name_index, time_steps)

    for (ix, d) in enumerate(inflow_data)
        name = get_name(d)
        multiplier[name, 1] = d.multiplier
        paraminflow[name, 1] = PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[1])
        exp =
            initial_conditions[ix].value +
            (
                multiplier[name, 1] * paraminflow[name, 1] - varspill[name, 1] -
                varout[name, 1]
            ) * fraction_of_hour
        constraint[name, 1] =
            JuMP.@constraint(psi_container.JuMPmodel, varenergy[name, 1] == exp)

        for t in time_steps[2:end]
            paraminflow[name, t] =
                PJ.add_parameter(psi_container.JuMPmodel, d.timeseries[t])
            exp =
                varenergy[name, t - 1] +
                (
                    d.multiplier * paraminflow[name, 1] - varspill[name, t] -
                    varout[name, t]
                ) * fraction_of_hour
            constraint[name, t] =
                JuMP.@constraint(psi_container.JuMPmodel, varenergy[name, t] == exp)
        end
    end
    return
end

@doc raw"""
Constructs multi-timestep constraint from initial condition, efficiency data, and variable tuple
# Constraints
If t = 1:
``` varenergy[name, 1] == initial_conditions[ix].value + (paraminflow[name, t] - varspill[name, 1] - varout[name, 1])*fraction_of_hour ```
If t > 1:
``` varenergy[name, t] == varenergy[name, t-1] + (paraminflow[name, t] - varspill[name, t] - varout[name, t])*fraction_of_hour ```
# LaTeX
`` x^{energy}_1 == x^{energy}_{init} + frhr  (x^{in}_1 - x^{spillage}_1 -  x^{out}_1), \text{ for } t = 1 ``
`` x^{energy}_t == x^{energy}_{t-1} + frhr (x^{in}_t - x^{spillage}_t - x^{out}_t), \forall t \geq 2 ``
# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varenergy'
* inflow_data::TVector{DeviceTimeSeriesConstraintInfo} :: Inflow energy forecast information
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : varspill
- : var_names[2] : varout
- : var_names[3] : varenergy
"""
function energy_balance_external_input!(
    psi_container::PSIContainer,
    initial_conditions::Vector{InitialCondition},
    inflow_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    name_index = (get_name(d) for d in inflow_data)

    varspill = get_variable(psi_container, var_names[1])
    varout = get_variable(psi_container, var_names[2])
    varenergy = get_variable(psi_container, var_names[3])

    constraint = add_cons_container!(psi_container, cons_name, name_index, time_steps)

    for (ix, d) in enumerate(inflow_data)
        name = get_name(d)
        constraint[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varenergy[name, 1] ==
            initial_conditions[ix].value +
            (d.multiplier * d.timeseries[1] - varspill[name, 1] - varout[name, 1]) *
            fraction_of_hour
        )

        for t in time_steps[2:end]
            constraint[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                varenergy[name, t] ==
                varenergy[name, t - 1] +
                (d.multiplier * d.timeseries[t] - varspill[name, t] - varout[name, t]) *
                fraction_of_hour
            )
        end
    end
    return
end
