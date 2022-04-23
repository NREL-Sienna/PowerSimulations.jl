function _get_minutes_per_period(container::OptimizationContainer)
    resolution = get_resolution(container)
    if resolution > Dates.Minute(1)
        minutes_per_period = Dates.value(Dates.Minute(resolution))
    else
        @warn("Not all formulations support under 1-minute resolutions. Exercise caution.")
        minutes_per_period = Dates.value(Dates.Second(resolution)) / 60
    end
    return minutes_per_period
end

function _get_ramp_constraint_devices(
    container::OptimizationContainer,
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
) where {U <: PSY.Component}
    minutes_per_period = _get_minutes_per_period(container)
    filtered_device = Vector{U}()
    for d in devices
        ramp_limits = PSY.get_ramp_limits(d)
        if ramp_limits !== nothing
            p_lims = PSY.get_active_power_limits(d)
            max_rate = abs(p_lims.min - p_lims.max) / minutes_per_period
            if (ramp_limits.up >= max_rate) & (ramp_limits.down >= max_rate)
                @debug "Generator has a nonbinding ramp limits. Constraints Skipped" PSY.get_name(
                    d,
                )
                continue
            else
                push!(filtered_device, d)
            end
        end
    end
    return filtered_device
end

@doc raw"""
Constructs allowed rate-of-change constraints from variables, initial condtions, and rate data.


If t = 1:

``` variable[name, 1] - initial_conditions[ix].value <= rate_data[1][ix].up ```

``` initial_conditions[ix].value - variable[name, 1] <= rate_data[1][ix].down ```

If t > 1:

``` variable[name, t] - variable[name, t-1] <= rate_data[1][ix].up ```

``` variable[name, t-1] - variable[name, t] <= rate_data[1][ix].down ```

# LaTeX

`` r^{down} \leq x_1 - x_{init} \leq r^{up}, \text{ for } t = 1 ``

`` r^{down} \leq x_t - x_{t-1} \leq r^{up}, \forall t \geq 2 ``

"""
function add_linear_ramp_constraints!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{S},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {
    S <: Union{PowerAboveMinimumVariable, ActivePowerVariable},
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
}
    parameters = built_for_recurrent_solves(container)
    time_steps = get_time_steps(container)
    variable = get_variable(container, U(), V)
    ramp_devices = _get_ramp_constraint_devices(container, devices)
    minutes_per_period = _get_minutes_per_period(container)
    IC = _get_initial_condition_type(T, V, W)
    initial_conditions_power = get_initial_condition(container, IC(), V)
    expr_dn = get_expression(container, ActivePowerRangeExpressionLB(), V)
    expr_up = get_expression(container, ActivePowerRangeExpressionUB(), V)

    set_name = [PSY.get_name(r) for r in ramp_devices]
    con_up = add_constraints_container!(container, T(), V, set_name, time_steps, meta="up")
    con_down =
        add_constraints_container!(container, T(), V, set_name, time_steps, meta="dn")

    for ic in initial_conditions_power
        name = get_component_name(ic)
        # This is to filter out devices that dont need a ramping constraint
        name ∉ set_name && continue
        ramp_limits = PSY.get_ramp_limits(get_component(ic))
        ic_power = get_value(ic)
        @debug "add rate_of_change_constraint" name ic_power
        @assert (parameters && isa(ic_power, PJ.ParameterRef)) || !parameters
        con_up[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            expr_up[name, 1] - ic_power <= ramp_limits.up * minutes_per_period
        )
        con_down[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            ic_power - expr_dn[name, 1] >= -1 * ramp_limits.down * minutes_per_period
        )
        for t in time_steps[2:end]
            con_up[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                expr_up[name, t] - variable[name, t - 1] <=
                ramp_limits.up * minutes_per_period
            )
            con_down[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, t - 1] - expr_dn[name, t] >=
                -1 * ramp_limits.down * minutes_per_period
            )
        end
    end
    return
end

function add_linear_ramp_constraints!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    parameters = built_for_recurrent_solves(container)
    time_steps = get_time_steps(container)
    variable = get_variable(container, U(), V)
    ramp_devices = _get_ramp_constraint_devices(container, devices)
    minutes_per_period = _get_minutes_per_period(container)
    IC = _get_initial_condition_type(T, V, W)
    initial_conditions_power = get_initial_condition(container, IC(), V)

    set_name = [PSY.get_name(r) for r in ramp_devices]
    con_up = add_constraints_container!(container, T(), V, set_name, time_steps, meta="up")
    con_down =
        add_constraints_container!(container, T(), V, set_name, time_steps, meta="dn")

    for ic in initial_conditions_power
        name = get_component_name(ic)
        # This is to filter out devices that dont need a ramping constraint
        name ∉ set_name && continue
        ramp_limits = PSY.get_ramp_limits(get_component(ic))
        ic_power = get_value(ic)
        @debug "add rate_of_change_constraint" name ic_power
        @assert (parameters && isa(ic_power, PJ.ParameterRef)) || !parameters
        con_up[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            variable[name, 1] - ic_power <= ramp_limits.up * minutes_per_period
        )
        con_down[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            ic_power - variable[name, 1] <= ramp_limits.down * minutes_per_period
        )
        for t in time_steps[2:end]
            con_up[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, t] - variable[name, t - 1] <=
                ramp_limits.up * minutes_per_period
            )
            con_down[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, t - 1] - variable[name, t] <=
                ramp_limits.down * minutes_per_period
            )
        end
    end
    return
end

@doc raw"""
Constructs allowed rate-of-change constraints from variables, initial condtions, start/stop status, and rate data

# Equations
If t = 1:

``` variable[name, 1] - initial_conditions[ix].value <= rate_data[1][ix].up + rate_data[2][ix].max*varstart[name, 1] ```

``` initial_conditions[ix].value - variable[name, 1] <= rate_data[1][ix].down + rate_data[2][ix].min*varstop[name, 1] ```

If t > 1:

``` variable[name, t] - variable[name, t-1] <= rate_data[1][ix].up + rate_data[2][ix].max*varstart[name, t] ```

``` variable[name, t-1] - variable[name, t] <= rate_data[1][ix].down + rate_data[2][ix].min*varstop[name, t] ```

# LaTeX

`` r^{down} + r^{min} x^{stop}_1 \leq x_1 - x_{init} \leq r^{up} + r^{max} x^{start}_1, \text{ for } t = 1 ``

`` r^{down} + r^{min} x^{stop}_t \leq x_t - x_{t-1} \leq r^{up} + r^{max} x^{start}_t, \forall t \geq 2 ``
"""
function add_semicontinuous_ramp_constraints!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{S},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {
    S <: Union{PowerAboveMinimumVariable, ActivePowerVariable},
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
}
    parameters = built_for_recurrent_solves(container)
    time_steps = get_time_steps(container)
    variable = get_variable(container, U(), V)
    varstart = get_variable(container, StartVariable(), V)
    varstop = get_variable(container, StopVariable(), V)

    ramp_devices = _get_ramp_constraint_devices(container, devices)
    minutes_per_period = _get_minutes_per_period(container)
    IC = _get_initial_condition_type(T, V, W)
    initial_conditions_power = get_initial_condition(container, IC(), V)
    expr_dn = get_expression(container, ActivePowerRangeExpressionLB(), V)
    expr_up = get_expression(container, ActivePowerRangeExpressionUB(), V)

    set_name = [PSY.get_name(r) for r in ramp_devices]
    con_up = add_constraints_container!(container, T(), V, set_name, time_steps, meta="up")
    con_down =
        add_constraints_container!(container, T(), V, set_name, time_steps, meta="dn")

    for ic in initial_conditions_power
        name = get_component_name(ic)
        # This is to filter out devices that dont need a ramping constraint
        name ∉ set_name && continue
        device = get_component(ic)
        ramp_limits = PSY.get_ramp_limits(device)
        power_limits = PSY.get_active_power_limits(device)
        ic_power = get_value(ic)
        @debug "add rate_of_change_constraint" name ic_power
        @assert (parameters && isa(ic_power, PJ.ParameterRef)) || !parameters
        con_up[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            expr_up[name, 1] - ic_power <=
            ramp_limits.up * minutes_per_period + power_limits.min * varstart[name, 1]
        )
        con_down[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            ic_power - expr_dn[name, 1] <=
            ramp_limits.down * minutes_per_period + power_limits.min * varstop[name, 1]
        )
        for t in time_steps[2:end]
            con_up[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                expr_up[name, t] - variable[name, t - 1] <=
                ramp_limits.up * minutes_per_period + power_limits.min * varstart[name, t]
            )
            con_down[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, t - 1] - expr_dn[name, t] <=
                ramp_limits.down * minutes_per_period + power_limits.min * varstop[name, t]
            )
        end
    end
    return
end

function add_semicontinuous_ramp_constraints!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    parameters = built_for_recurrent_solves(container)
    time_steps = get_time_steps(container)
    variable = get_variable(container, U(), V)
    varstart = get_variable(container, StartVariable(), V)
    varstop = get_variable(container, StopVariable(), V)

    ramp_devices = _get_ramp_constraint_devices(container, devices)
    minutes_per_period = _get_minutes_per_period(container)
    IC = _get_initial_condition_type(T, V, W)
    initial_conditions_power = get_initial_condition(container, IC(), V)

    set_name = [PSY.get_name(r) for r in ramp_devices]
    con_up = add_constraints_container!(container, T(), V, set_name, time_steps, meta="up")
    con_down =
        add_constraints_container!(container, T(), V, set_name, time_steps, meta="dn")

    for ic in initial_conditions_power
        name = get_component_name(ic)
        # This is to filter out devices that dont need a ramping constraint
        name ∉ set_name && continue
        device = get_component(ic)
        ramp_limits = PSY.get_ramp_limits(device)
        power_limits = PSY.get_active_power_limits(device)
        ic_power = get_value(ic)
        @debug "add rate_of_change_constraint" name ic_power
        @assert (parameters && isa(ic_power, PJ.ParameterRef)) || !parameters
        con_up[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            variable[name, 1] - ic_power <=
            ramp_limits.up * minutes_per_period + power_limits.min * varstart[name, 1]
        )
        con_down[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            ic_power - variable[name, 1] <=
            ramp_limits.down * minutes_per_period + power_limits.min * varstop[name, 1]
        )
        for t in time_steps[2:end]
            con_up[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, t] - variable[name, t - 1] <=
                ramp_limits.up * minutes_per_period + power_limits.min * varstart[name, t]
            )
            con_down[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, t - 1] - variable[name, t] <=
                ramp_limits.down * minutes_per_period + power_limits.min * varstop[name, t]
            )
        end
    end
    return
end
