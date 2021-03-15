struct DeviceEnergyBalanceConstraintSpec
    constraint_name::Symbol
    energy_variable::Symbol
    initial_condition::Type{<:InitialConditionType}
    pin_variable_names::Vector{Symbol}
    pout_variable_names::Vector{Symbol}
    parameter_name::Union{Nothing, String}
    forecast_label::Union{Nothing, String}
    multiplier_func::Union{Nothing, Function}
    constraint_func::Function
end

function DeviceEnergyBalanceConstraintSpec(;
    constraint_name::Symbol,
    energy_variable::Symbol,
    initial_condition::Type{<:InitialConditionType},
    constraint_func::Function,
    pin_variable_names::Vector{Symbol} = Vector{Symbol}(),
    pout_variable_names::Vector{Symbol} = Vector{Symbol}(),
    parameter_name::Union{Nothing, String} = nothing,
    forecast_label::Union{Nothing, String} = nothing,
    multiplier_func::Union{Nothing, Function} = nothing,
)
    return DeviceEnergyBalanceConstraintSpec(
        constraint_name,
        energy_variable,
        initial_condition,
        pin_variable_names,
        pout_variable_names,
        parameter_name,
        forecast_label,
        multiplier_func,
        constraint_func,
    )
end

function add_constraints!(
    optimization_container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    T <: EnergyBalanceConstraint,
    U <: VariableType,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    use_parameters = model_has_parameters(optimization_container)
    use_forecasts = model_uses_forecasts(optimization_container)
    # @assert !(use_parameters && !use_forecasts)
    spec = DeviceEnergyBalanceConstraintSpec(
        T,
        U,
        V,
        W,
        X,
        feedforward,
        use_parameters,
        use_forecasts,
    )
    energy_balance_constraints!(optimization_container, devices, model, feedforward, spec)
end

function energy_balance_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    spec::DeviceEnergyBalanceConstraintSpec,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    initial_conditions =
        get_initial_conditions(optimization_container, spec.initial_condition, T)
    _apply_energy_balance_constraint_spec!(
        optimization_container,
        spec,
        devices,
        initial_conditions,
        model,
        feedforward,
    )
end

struct DeviceEnergyBalanceConstraintSpecInternal
    constraint_infos::Vector{<:EnergyBalanceConstraintInfo}
    constraint_name::Symbol
    energy_variable::Symbol
    pin_variable_names::Vector{Symbol}
    pout_variable_names::Vector{Symbol}
    param_reference::Union{Nothing, UpdateRef}
end

function _apply_energy_balance_constraint_spec!(
    optimization_container,
    spec,
    devices::IS.FlattenIteratorWrapper{T},
    initial_conditions::Vector{InitialCondition},
    model,
    ff_affected_variables,
) where {T <: PSY.Device}
    constraint_infos = Vector{EnergyBalanceConstraintInfo}(undef, length(devices))
    for (ix, ic) in enumerate(initial_conditions)
        device = ic.device
        dev_name = PSY.get_name(device)
        if !isnothing(spec.forecast_label)
            ts_vector = get_time_series(optimization_container, device, spec.forecast_label)
            multiplier = spec.multiplier_func(device)
            constraint_info = EnergyBalanceConstraintInfo(
                dev_name,
                get_efficiency(device, spec.initial_condition),
                ic,
                multiplier,
                ts_vector,
            )
        else
            constraint_info = EnergyBalanceConstraintInfo(;
                component_name = dev_name,
                efficiency_data = get_efficiency(device, spec.initial_condition),
                ic_energy = ic,
            )
        end
        constraint_infos[ix] = constraint_info
    end

    spec.constraint_func(
        optimization_container,
        DeviceEnergyBalanceConstraintSpecInternal(
            constraint_infos,
            spec.constraint_name,
            spec.energy_variable,
            spec.pin_variable_names,
            spec.pout_variable_names,
            spec.parameter_name === nothing ? nothing :
            UpdateRef{T}(spec.parameter_name, spec.forecast_label),
        ),
    )
    return
end

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
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* inputs::Vector{DeviceEnergyBalanceConstraintSpecInternal} : stores constraint information 
"""
function energy_balance!(
    optimization_container::OptimizationContainer,
    inputs::DeviceEnergyBalanceConstraintSpecInternal,
)
    time_steps = model_time_steps(optimization_container)
    resolution = model_resolution(optimization_container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [get_component_name(x) for x in inputs.constraint_infos]

    varenergy = get_variable(optimization_container, inputs.energy_variable)
    varin = [get_variable(optimization_container, var) for var in inputs.pin_variable_names]
    varout =
        [get_variable(optimization_container, var) for var in inputs.pout_variable_names]

    constraint = add_cons_container!(
        optimization_container,
        inputs.constraint_name,
        names,
        time_steps,
    )

    for info in inputs.constraint_infos
        eff_in = info.efficiency_data.in
        eff_out = info.efficiency_data.out
        name = get_component_name(info)
        # Create the PGAE outside of the constraint definition
        !isnothing(info.timeseries) ? ts_value = info.timeseries[1] * info.multiplier :
        ts_value = 0.0
        expr = JuMP.AffExpr(0.0)
        for var in varin
            JuMP.add_to_expression!(expr, var[name, 1], eff_in * fraction_of_hour)
        end
        for var in varout
            JuMP.add_to_expression!(expr, var[name, 1], -1.0 * fraction_of_hour / eff_out)
        end
        constraint[name, 1] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy[name, 1] == info.ic_energy.value + expr + ts_value
        )
    end

    for t in time_steps[2:end], info in inputs.constraint_infos
        eff_in = info.efficiency_data.in
        eff_out = info.efficiency_data.out
        name = get_component_name(info)
        !isnothing(info.timeseries) ? ts_value = info.timeseries[t] * info.multiplier :
        ts_value = 0.0
        expr = JuMP.AffExpr(0.0, varenergy[name, t - 1] => 1.0)
        for var in varin
            JuMP.add_to_expression!(expr, var[name, t], eff_in * fraction_of_hour)
        end
        for var in varout
            JuMP.add_to_expression!(expr, var[name, t], -1.0 * fraction_of_hour / eff_out)
        end
        constraint[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy[name, t] == expr + ts_value
        )
    end

    return
end

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
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* inputs::Vector{DeviceEnergyBalanceConstraintSpecInternal} : stores constraint information 
"""
function energy_balance_param!(
    optimization_container::OptimizationContainer,
    inputs::DeviceEnergyBalanceConstraintSpecInternal,
)
    time_steps = model_time_steps(optimization_container)
    resolution = model_resolution(optimization_container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [get_component_name(x) for x in inputs.constraint_infos]
    has_parameter_data = !isnothing(inputs.param_reference)

    varenergy = get_variable(optimization_container, inputs.energy_variable)
    varin = [get_variable(optimization_container, var) for var in inputs.pin_variable_names]
    varout =
        [get_variable(optimization_container, var) for var in inputs.pout_variable_names]

    if has_parameter_data
        container = add_param_container!(
            optimization_container,
            inputs.param_reference,
            names,
            time_steps,
        )
        multiplier = get_multiplier_array(container)
        param = get_parameter_array(container)
    end

    constraint = add_cons_container!(
        optimization_container,
        inputs.constraint_name,
        names,
        time_steps,
    )

    for info in inputs.constraint_infos
        eff_in = info.efficiency_data.in
        eff_out = info.efficiency_data.out
        name = get_component_name(info)
        # Create the PGAE outside of the constraint definition
        expr = zero(PGAE)
        for var in varin
            JuMP.add_to_expression!(expr, var[name, 1], eff_in * fraction_of_hour)
        end
        for var in varout
            JuMP.add_to_expression!(expr, var[name, 1], -1 * fraction_of_hour / eff_out)
        end
        if has_parameter_data
            multiplier[name, 1] = info.multiplier
            param[name, 1] =
                PJ.add_parameter(optimization_container.JuMPmodel, info.timeseries[1])
            JuMP.add_to_expression!(expr, param[name, 1], multiplier[name, 1])
        end
        constraint[name, 1] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy[name, 1] == info.ic_energy.value + expr
        )
    end

    for t in time_steps[2:end], info in inputs.constraint_infos
        eff_in = info.efficiency_data.in
        eff_out = info.efficiency_data.out
        name = get_component_name(info)
        expr = expr = zero(PGAE)
        JuMP.add_to_expression!(expr, varenergy[name, t - 1])
        for var in varin
            JuMP.add_to_expression!(expr, var[name, t], eff_in * fraction_of_hour)
        end
        for var in varout
            JuMP.add_to_expression!(expr, var[name, t], -1 * fraction_of_hour / eff_out)
        end
        if has_parameter_data
            multiplier[name, t] = info.multiplier
            param[name, t] =
                PJ.add_parameter(optimization_container.JuMPmodel, info.timeseries[t])
            JuMP.add_to_expression!(expr, param[name, t], multiplier[name, t])
        end
        constraint[name, t] =
            JuMP.@constraint(optimization_container.JuMPmodel, varenergy[name, t] == expr)
    end

    return
end

########## Old constraint function that will be deleted after storage refactor is complete

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
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varenergy'
* efficiency_data::Tuple{Vector{String}, Vector{InOut}} :: charging/discharging efficiencies
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : varin
- : var_names[2] : varout
- : var_names[3] : varenergy

"""
function energy_balance(
    optimization_container::OptimizationContainer,
    initial_conditions::Vector{InitialCondition},
    efficiency_data::Tuple{Vector{String}, Vector{InOut}},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    parameters = model_has_parameters(optimization_container)
    time_steps = model_time_steps(optimization_container)
    resolution = model_resolution(optimization_container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    name_index = efficiency_data[1]

    varin = get_variable(optimization_container, var_names[1])
    varout = get_variable(optimization_container, var_names[2])
    varenergy = get_variable(optimization_container, var_names[3])

    constraint =
        add_cons_container!(optimization_container, cons_name, name_index, time_steps)

    for (ix, name) in enumerate(name_index)
        eff_in = efficiency_data[2][ix].in
        eff_out = efficiency_data[2][ix].out
        # Create the PGAE outside of the constraint definition
        balance =
            initial_conditions[ix].value + varin[name, 1] * eff_in * fraction_of_hour -
            (varout[name, 1]) * fraction_of_hour / eff_out
        constraint[name, 1] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy[name, 1] == balance
        )
    end

    for t in time_steps[2:end], (ix, name) in enumerate(name_index)
        eff_in = efficiency_data[2][ix].in
        eff_out = efficiency_data[2][ix].out

        constraint[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
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
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
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
    optimization_container::OptimizationContainer,
    initial_conditions::Vector{InitialCondition},
    time_series_data::Tuple{
        Vector{DeviceTimeSeriesConstraintInfo},
        Vector{DeviceTimeSeriesConstraintInfo},
    },
    cons_names::Tuple{Symbol, Symbol},
    var_names::Tuple{Symbol, Symbol, Symbol},
    param_references::Tuple{UpdateRef, UpdateRef},
)
    time_steps = model_time_steps(optimization_container)
    resolution = model_resolution(optimization_container)
    fraction_of_hour = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR

    inflow_data = time_series_data[1]
    target_data = time_series_data[2]

    name_index = [get_component_name(d) for d in inflow_data]

    varspill = get_variable(optimization_container, var_names[1])
    varout = get_variable(optimization_container, var_names[2])
    varenergy = get_variable(optimization_container, var_names[3])

    balance_cons_name = cons_names[1]
    target_cons_name = cons_names[2]
    balance_param_reference = param_references[1]
    target_param_reference = param_references[2]

    container_inflow = add_param_container!(
        optimization_container,
        balance_param_reference,
        name_index,
        time_steps,
    )
    param_inflow = get_parameter_array(container_inflow)
    multiplier_inflow = get_multiplier_array(container_inflow)
    container_target = add_param_container!(
        optimization_container,
        target_param_reference,
        name_index,
        time_steps,
    )
    param_target = get_parameter_array(container_target)
    multiplier_target = get_multiplier_array(container_target)

    balance_constraint = add_cons_container!(
        optimization_container,
        balance_cons_name,
        name_index,
        time_steps,
    )
    target_constraint =
        add_cons_container!(optimization_container, target_cons_name, name_index, 1)

    for (ix, d) in enumerate(inflow_data)
        name = get_component_name(d)
        multiplier_inflow[name, 1] = d.multiplier
        param_inflow[name, 1] =
            add_parameter(optimization_container.JuMPmodel, d.timeseries[1])
        exp =
            initial_conditions[ix].value +
            (
                multiplier_inflow[name, 1] * param_inflow[name, 1] - varspill[name, 1] -
                varout[name, 1]
            ) * fraction_of_hour
        balance_constraint[name, 1] =
            JuMP.@constraint(optimization_container.JuMPmodel, varenergy[name, 1] == exp)

        for t in time_steps[2:end]
            multiplier_inflow[name, t] = d.multiplier
            param_inflow[name, t] =
                add_parameter(optimization_container.JuMPmodel, d.timeseries[t])
            exp =
                varenergy[name, t - 1] +
                (
                    multiplier_inflow[name, t] * param_inflow[name, t] - varspill[name, t] -
                    varout[name, t]
                ) * fraction_of_hour
            balance_constraint[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                varenergy[name, t] == exp
            )
        end
    end

    for (ix, d) in enumerate(target_data)
        name = get_component_name(d)
        for t in time_steps
            param_target[name, t] =
                add_parameter(optimization_container.JuMPmodel, d.timeseries[t])
            multiplier_target[name, t] = d.multiplier
        end
        target_constraint[name, 1] = JuMP.@constraint(
            optimization_container.JuMPmodel,
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
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
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
    optimization_container::OptimizationContainer,
    initial_conditions::Vector{InitialCondition},
    time_series_data::Tuple{
        Vector{DeviceTimeSeriesConstraintInfo},
        Vector{DeviceTimeSeriesConstraintInfo},
    },
    cons_names::Tuple{Symbol, Symbol},
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(optimization_container)
    resolution = model_resolution(optimization_container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR

    inflow_data = time_series_data[1]
    target_data = time_series_data[2]

    name_index = [get_component_name(d) for d in inflow_data]

    varspill = get_variable(optimization_container, var_names[1])
    varout = get_variable(optimization_container, var_names[2])
    varenergy = get_variable(optimization_container, var_names[3])

    balance_cons_name = cons_names[1]
    target_cons_name = cons_names[2]

    balance_constraint = add_cons_container!(
        optimization_container,
        balance_cons_name,
        name_index,
        time_steps,
    )
    target_constraint =
        add_cons_container!(optimization_container, target_cons_name, name_index, 1)

    for (ix, d) in enumerate(inflow_data)
        name = get_component_name(d)
        balance_constraint[name, 1] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy[name, 1] ==
            initial_conditions[ix].value +
            (d.multiplier * d.timeseries[1] - varspill[name, 1] - varout[name, 1]) *
            fraction_of_hour
        )

        for t in time_steps[2:end]
            balance_constraint[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
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
            optimization_container.JuMPmodel,
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
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
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
    optimization_container::OptimizationContainer,
    initial_conditions::Vector{InitialCondition},
    ts_data::Tuple{
        Vector{DeviceTimeSeriesConstraintInfo},
        Vector{DeviceTimeSeriesConstraintInfo},
    },
    cons_name::Tuple{Symbol, Symbol},
    var_names::Tuple{Symbol, Symbol, Symbol, Symbol, Symbol},
    param_reference::Tuple{UpdateRef, UpdateRef},
)
    time_steps = model_time_steps(optimization_container)
    resolution = model_resolution(optimization_container)
    fraction_of_hour = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    inflow_data = ts_data[1]
    outflow_data = ts_data[2]
    inflow_name_index = [get_component_name(d) for d in inflow_data]
    outflow_name_index = [get_component_name(d) for d in outflow_data]

    varspill = get_variable(optimization_container, var_names[1])
    varout = get_variable(optimization_container, var_names[2])
    varenergy_up = get_variable(optimization_container, var_names[3])
    varin = get_variable(optimization_container, var_names[4])
    varenergy_down = get_variable(optimization_container, var_names[5])

    container_inflow = add_param_container!(
        optimization_container,
        param_reference[1],
        inflow_name_index,
        time_steps,
    )
    param_inflow = get_parameter_array(container_inflow)
    multiplier_inflow = get_multiplier_array(container_inflow)
    container_outflow = add_param_container!(
        optimization_container,
        param_reference[2],
        outflow_name_index,
        time_steps,
    )
    param_outflow = get_parameter_array(container_outflow)
    multiplier_outflow = get_multiplier_array(container_outflow)
    constraint_up = add_cons_container!(
        optimization_container,
        cons_name[1],
        inflow_name_index,
        time_steps,
    )
    constraint_down = add_cons_container!(
        optimization_container,
        cons_name[2],
        outflow_name_index,
        time_steps,
    )

    for (ix, d) in enumerate(inflow_data)
        name = get_component_name(d)
        pump_eff = 1.0 # TODO: get pump efficiency PSY.get_pump_efficiency(d)
        multiplier_inflow[name, 1] = d.multiplier
        param_inflow[name, 1] =
            add_parameter(optimization_container.JuMPmodel, d.timeseries[1])
        exp =
            initial_conditions[ix].value +
            (
                multiplier_inflow[name, 1] * param_inflow[name, 1] +
                varin[name, 1] * pump_eff - varspill[name, 1] - varout[name, 1]
            ) * fraction_of_hour
        constraint_up[name, 1] =
            JuMP.@constraint(optimization_container.JuMPmodel, varenergy_up[name, 1] == exp)

        for t in time_steps[2:end]
            multiplier_inflow[name, t] = d.multiplier
            param_inflow[name, t] =
                add_parameter(optimization_container.JuMPmodel, d.timeseries[t])
            exp =
                varenergy_up[name, t - 1] +
                (
                    multiplier_inflow[name, t] * param_inflow[name, t] +
                    varin[name, t] * pump_eff - varspill[name, t] - varout[name, t]
                ) * fraction_of_hour
            constraint_up[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                varenergy_up[name, t] == exp
            )
        end
    end

    for (ix, d) in enumerate(outflow_data)
        name = get_component_name(d)
        pump_eff = 1.0 # TODO: get pump efficiency PSY.get_pump_efficiency(d)
        multiplier_outflow[name, 1] = d.multiplier
        param_outflow[name, 1] =
            add_parameter(optimization_container.JuMPmodel, d.timeseries[1])
        exp =
            initial_conditions[ix].value +
            (
                varspill[name, 1] + varout[name, 1] -
                multiplier_outflow[name, 1] * param_outflow[name, 1] -
                varin[name, 1] * pump_eff
            ) * fraction_of_hour
        constraint_down[name, 1] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy_down[name, 1] == exp
        )

        for t in time_steps[2:end]
            multiplier_outflow[name, t] = d.multiplier
            param_outflow[name, t] =
                add_parameter(optimization_container.JuMPmodel, d.timeseries[t])
            exp =
                varenergy_down[name, t - 1] +
                (
                    varspill[name, t] + varout[name, t] -
                    multiplier_outflow[name, t] * param_outflow[name, t] -
                    varin[name, t] * pump_eff
                ) * fraction_of_hour
            constraint_down[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                varenergy_down[name, t] == exp
            )
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
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
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
    optimization_container::OptimizationContainer,
    initial_conditions::Vector{InitialCondition},
    ts_data::Tuple{
        Vector{DeviceTimeSeriesConstraintInfo},
        Vector{DeviceTimeSeriesConstraintInfo},
    },
    cons_name::Tuple{Symbol, Symbol},
    var_names::Tuple{Symbol, Symbol, Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(optimization_container)
    resolution = model_resolution(optimization_container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    inflow_data = ts_data[1]
    outflow_data = ts_data[2]
    inflow_name_index = [get_component_name(d) for d in inflow_data]
    outflow_name_index = [get_component_name(d) for d in outflow_data]

    varspill = get_variable(optimization_container, var_names[1])
    varout = get_variable(optimization_container, var_names[2])
    varenergy_up = get_variable(optimization_container, var_names[3])
    varin = get_variable(optimization_container, var_names[4])
    varenergy_down = get_variable(optimization_container, var_names[5])

    constraint_up = add_cons_container!(
        optimization_container,
        cons_name[1],
        inflow_name_index,
        time_steps,
    )
    constraint_down = add_cons_container!(
        optimization_container,
        cons_name[2],
        outflow_name_index,
        time_steps,
    )

    for (ix, d) in enumerate(inflow_data)
        name = get_component_name(d)
        pump_eff = 1.0 # TODO: get pump efficiency PSY.get_pump_efficiency(d)
        constraint_up[name, 1] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy_up[name, 1] ==
            initial_conditions[ix].value +
            (
                d.multiplier * d.timeseries[1] + varin[name, 1] * pump_eff -
                varspill[name, 1] - varout[name, 1]
            ) * fraction_of_hour
        )

        for t in time_steps[2:end]
            constraint_up[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
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
            optimization_container.JuMPmodel,
            varenergy_down[name, 1] ==
            initial_conditions[ix].value +
            (
                varspill[name, 1] + varout[name, 1] - d.multiplier * d.timeseries[1] -
                varin[name, 1] * pump_eff
            ) * fraction_of_hour
        )

        for t in time_steps[2:end]
            constraint_down[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
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
