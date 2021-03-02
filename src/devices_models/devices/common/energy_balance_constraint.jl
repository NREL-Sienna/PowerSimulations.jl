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
    subcomponent_type::Union{Nothing, Type{<:PSY.Component}}
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
    subcomponent_type::Union{Nothing, Type{<:PSY.Component}} = nothing,
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
        subcomponent_type,
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
    subcomponent_type::Union{Nothing, Type{<:PSY.Component}}
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
            spec.subcomponent_type,
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
        idx = get_index(name, 1, inputs.subcomponent_type)
        # Create the PGAE outside of the constraint definition
        !isnothing(info.timeseries) ? ts_value = info.timeseries[1] * info.multiplier :
        ts_value = 0.0
        expr = JuMP.AffExpr(0.0)
        for var in varin
            JuMP.add_to_expression!(expr, var[idx], eff_in * fraction_of_hour)
        end
        for var in varout
            JuMP.add_to_expression!(expr, var[idx], -1.0 * fraction_of_hour / eff_out)
        end
        constraint[name, 1] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy[idx] == info.ic_energy.value + expr + ts_value
        )
    end

    for t in time_steps[2:end], info in inputs.constraint_infos
        eff_in = info.efficiency_data.in
        eff_out = info.efficiency_data.out
        name = get_component_name(info)
        idx = get_index(name, t, inputs.subcomponent_type)
        idx_ = get_index(name, t - 1, inputs.subcomponent_type)
        !isnothing(info.timeseries) ? ts_value = info.timeseries[t] * info.multiplier :
        ts_value = 0.0

        expr = JuMP.AffExpr(0.0, varenergy[idx_] => 1.0)
        for var in varin
            JuMP.add_to_expression!(expr, var[idx], eff_in * fraction_of_hour)
        end
        for var in varout
            JuMP.add_to_expression!(expr, var[idx], -1.0 * fraction_of_hour / eff_out)
        end
        constraint[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy[idx] == expr + ts_value
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
        idx = get_index(name, 1, inputs.subcomponent_type)
        # Create the PGAE outside of the constraint definition
        expr = zero(PGAE)
        for var in varin
            JuMP.add_to_expression!(expr, var[idx], eff_in * fraction_of_hour)
        end
        for var in varout
            JuMP.add_to_expression!(expr, var[idx], -1 * fraction_of_hour / eff_out)
        end
        if has_parameter_data
            multiplier[name, 1] = info.multiplier
            param[name, 1] =
                PJ.add_parameter(optimization_container.JuMPmodel, info.timeseries[1])
            JuMP.add_to_expression!(expr, param[name, 1], multiplier[name, 1])
        end
        constraint[name, 1] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varenergy[idx] == info.ic_energy.value + expr
        )
    end

    for t in time_steps[2:end], info in inputs.constraint_infos
        eff_in = info.efficiency_data.in
        eff_out = info.efficiency_data.out
        name = get_component_name(info)
        idx = get_index(name, t, inputs.subcomponent_type)
        _idx = get_index(name, t - 1, inputs.subcomponent_type)
        expr = zero(PGAE)
        JuMP.add_to_expression!(expr, varenergy[_idx])
        for var in varin
            JuMP.add_to_expression!(expr, var[idx], eff_in * fraction_of_hour)
        end
        for var in varout
            JuMP.add_to_expression!(expr, var[idx], -1 * fraction_of_hour / eff_out)
        end
        if has_parameter_data
            multiplier[name, t] = info.multiplier
            param[name, t] =
                PJ.add_parameter(optimization_container.JuMPmodel, info.timeseries[t])
            JuMP.add_to_expression!(expr, param[name, t], multiplier[name, t])
        end
        constraint[name, t] =
            JuMP.@constraint(optimization_container.JuMPmodel, varenergy[idx] == expr)
    end

    return
end
