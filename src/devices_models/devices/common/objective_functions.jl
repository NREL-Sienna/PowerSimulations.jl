function add_variable_cost!(
    container::OptimizationContainer,
    ::U,
    devices::IS.FlattenIteratorWrapper{T},
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    for d in devices
        op_cost_data = PSY.get_operation_cost(d)
        _add_variable_cost_to_objective!(container, U(), d, op_cost_data, V())
    end
    return
end

function add_variable_cost!(
    container::OptimizationContainer,
    ::U,
    service::T,
    ::V,
) where {T <: PSY.ReserveDemandCurve, U <: VariableType, V <: StepwiseCostReserve}
    _add_variable_cost_to_objective!(container, U(), service, V())
    return
end

function add_shut_down_cost!(
    container::OptimizationContainer,
    ::U,
    devices::IS.FlattenIteratorWrapper{T},
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    for d in devices
        op_cost_data = PSY.get_operation_cost(d)
        cost_term = shut_down_cost(op_cost_data, d, V())
        iszero(cost_term) && continue
        for t in get_time_steps(container)
            _add_proportional_term!(container, U(), d, cost_term * multiplier, t)
        end
    end
    return
end

function add_proportional_cost!(
    container::OptimizationContainer,
    ::U,
    devices::IS.FlattenIteratorWrapper{T},
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    for d in devices
        op_cost_data = PSY.get_operation_cost(d)
        cost_term = proportional_cost(op_cost_data, U(), d, V())
        iszero(cost_term) && continue
        for t in get_time_steps(container)
            _add_proportional_term!(container, U(), d, cost_term * multiplier, t)
        end
    end
    return
end

function add_proportional_cost!(
    container::OptimizationContainer,
    ::U,
    devices::IS.FlattenIteratorWrapper{T},
    ::V,
) where {T <: PSY.ThermalGen, U <: OnVariable, V <: AbstractCompactUnitCommitment}
    multiplier = objective_function_multiplier(U(), V())
    for d in devices
        op_cost_data = PSY.get_operation_cost(d)
        cost_term = proportional_cost(op_cost_data, U(), d, V())
        iszero(cost_term) && continue
        for t in get_time_steps(container)
            exp = _add_proportional_term!(container, U(), d, cost_term * multiplier, t)
            add_to_expression!(container, ProductionCostExpression, exp, d, t)
        end
    end
    return
end

function add_proportional_cost!(
    container::OptimizationContainer,
    ::U,
    devices::IS.FlattenIteratorWrapper{T},
    ::V,
) where {
    T <: PSY.Storage,
    U <: Union{ActivePowerInVariable, ActivePowerOutVariable},
    V <: AbstractDeviceFormulation,
}
    multiplier = objective_function_multiplier(U(), V())
    for d in devices
        for t in get_time_steps(container)
            _add_proportional_term!(container, U(), d, COST_EPSILON * multiplier, t)
        end
    end
    return
end

function add_proportional_cost!(
    container::OptimizationContainer,
    ::U,
    devices::IS.FlattenIteratorWrapper{T},
    ::V,
) where {
    T <: PSY.Component,
    U <: Union{EnergySurplusVariable, EnergyShortageVariable},
    V <: AbstractDeviceFormulation,
}
    base_p = get_base_power(container)
    multiplier = objective_function_multiplier(U(), V())
    for d in devices
        op_cost_data = PSY.get_operation_cost(d)
        cost_term = proportional_cost(op_cost_data, U(), d, V())
        iszero(cost_term) && continue
        for t in get_time_steps(container)
            _add_proportional_term!(container, U(), d, cost_term * multiplier * base_p, t)
        end
    end
    return
end

function add_proportional_cost!(
    container::OptimizationContainer,
    ::U,
    service::T,
    ::V,
) where {
    T <: Union{PSY.Reserve, PSY.ReserveNonSpinning},
    U <: ActivePowerReserveVariable,
    V <: AbstractReservesFormulation,
}
    base_p = get_base_power(container)
    reserve_variable = get_variable(container, U(), T, PSY.get_name(service))
    for index in Iterators.product(axes(reserve_variable)...)
        add_to_objective_invariant_expression!(
            container,
            DEFAULT_RESERVE_COST / base_p * reserve_variable[index...],
        )
    end
    return
end

function add_proportional_cost!(
    container::OptimizationContainer,
    ::U,
    areas::IS.FlattenIteratorWrapper{T},
    ::PIDSmoothACE,
) where {T <: PSY.Area, U <: LiftVariable}
    lift_variable = get_variable(container, U(), T)
    for index in Iterators.product(axes(lift_variable)...)
        add_to_objective_invariant_expression!(
            container,
            SERVICES_SLACK_COST * lift_variable[index...],
        )
    end
    return
end

function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    op_cost::PSY.OperationalCost,
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    variable_cost_data = variable_cost(op_cost, T(), component, U())
    _add_variable_cost_to_objective!(container, T(), component, variable_cost_data, U())
    return
end

function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    op_cost::PSY.MarketBidCost,
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    component_name = PSY.get_name(component)
    @debug "Market Bid" _group = LOG_GROUP_COST_FUNCTIONS component_name
    time_steps = get_time_steps(container)
    initial_time = get_initial_time(container)
    variable_cost_forecast = PSY.get_variable_cost(
        component,
        op_cost;
        start_time=initial_time,
        len=length(time_steps),
    )
    variable_cost_forecast_values = TimeSeries.values(variable_cost_forecast)
    parameter_container = _get_cost_function_parameter_container(
        container,
        CostFunctionParameter(),
        component,
        T(),
        U(),
        eltype(variable_cost_forecast_values),
    )
    pwl_cost_expressions =
        _add_pwl_term!(container, component, variable_cost_forecast_values, T(), U())
    jump_model = get_jump_model(container)
    for t in time_steps
        set_parameter!(
            parameter_container,
            jump_model,
            PSY.get_cost(variable_cost_forecast_values[t]),
            # Using 1.0 here since we want to reuse the existing code that adds the mulitpler
            #  of base power times the time delta.
            1.0,
            component_name,
            t,
        )
        add_to_expression!(
            container,
            ProductionCostExpression,
            pwl_cost_expressions[t],
            component,
            t,
        )
        add_to_objective_variant_expression!(container, pwl_cost_expressions[t])
    end

    # Service Cost Bid
    ancillary_services = PSY.get_ancillary_services(op_cost)
    for service in ancillary_services
        _add_service_bid_cost!(container, component, service)
    end
    return
end

function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Reserve,
    ::U,
) where {T <: VariableType, U <: StepwiseCostReserve}
    component_name = PSY.get_name(component)
    @debug "PWL Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    # If array is full of tuples with zeros return 0.0
    time_steps = get_time_steps(container)
    initial_time = get_initial_time(container)
    variable_cost_forecast = get_time_series(container, component, "variable_cost")
    variable_cost_forecast_values = TimeSeries.values(variable_cost_forecast)
    variable_cost_forecast_values = map(PSY.VariableCost, variable_cost_forecast_values)
    parameter_container = _get_cost_function_parameter_container(
        container,
        CostFunctionParameter(),
        component,
        T(),
        U(),
        eltype(variable_cost_forecast_values),
    )
    pwl_cost_expressions =
        _add_pwl_term!(container, component, variable_cost_forecast_values, T(), U())
    jump_model = get_jump_model(container)
    for t in time_steps
        set_parameter!(
            parameter_container,
            jump_model,
            PSY.get_cost(variable_cost_forecast_values[t]),
            # Using 1.0 here since we want to reuse the existing code that adds the mulitpler
            #  of base power times the time delta.
            1.0,
            component_name,
            t,
        )
        add_to_objective_variant_expression!(container, pwl_cost_expressions[t])
    end
    return
end

function add_start_up_cost!(
    container::OptimizationContainer,
    ::U,
    devices::IS.FlattenIteratorWrapper{T},
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    for d in devices
        op_cost_data = PSY.get_operation_cost(d)
        _add_start_up_cost_to_objective!(container, U(), d, op_cost_data, V())
    end
    return
end

function _add_start_up_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    op_cost::PSY.OperationalCost,
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    cost_term = start_up_cost(op_cost, component, U())
    iszero(cost_term) && return
    multiplier = objective_function_multiplier(T(), U())
    for t in get_time_steps(container)
        _add_proportional_term!(container, T(), component, cost_term * multiplier, t)
    end
    return
end

const MULTI_START_COST_MAP = Dict{DataType, Int}(
    HotStartVariable => 1,
    WarmStartVariable => 2,
    ColdStartVariable => 3,
)

function _add_start_up_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    op_cost::Union{PSY.MultiStartCost, PSY.MarketBidCost},
    ::U,
) where {T <: VariableType, U <: ThermalMultiStartUnitCommitment}
    cost_terms = start_up_cost(op_cost, component, U())
    cost_term = cost_terms[MULTI_START_COST_MAP[T]]
    iszero(cost_term) && return
    multiplier = objective_function_multiplier(T(), U())
    for t in get_time_steps(container)
        _add_proportional_term!(container, T(), component, cost_term * multiplier, t)
    end
    return
end

_get_cost_function_data_type(::Type{PSY.VariableCost{T}}) where {T} = T

function _get_cost_function_parameter_container(
    container::OptimizationContainer,
    ::S,
    component::T,
    ::U,
    ::V,
    cost_type::DataType,
) where {
    S <: ObjectiveFunctionParameter,
    T <: PSY.Component,
    U <: VariableType,
    V <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
}
    if has_container_key(container, S, T)
        return get_parameter(container, S(), T)
    else
        container_axes = axes(get_variable(container, U(), T))
        if has_container_key(container, OnStatusParameter, T)
            sos_val = SOSStatusVariable.PARAMETER
        else
            sos_val = sos_status(component, V())
        end
        return add_param_container!(
            container,
            S(),
            T,
            sos_val,
            U,
            uses_compact_power(component, V()),
            _get_cost_function_data_type(cost_type),
            container_axes...,
        )
    end
end

function _add_service_bid_cost!(
    container::OptimizationContainer,
    component::PSY.Component,
    service::PSY.Reserve{T},
) where {T <: PSY.ReserveDirection}
    time_steps = get_time_steps(container)
    initial_time = get_initial_time(container)
    base_power = get_base_power(container)
    forecast_data = PSY.get_services_bid(
        component,
        PSY.get_operation_cost(component),
        service;
        start_time=initial_time,
        len=length(time_steps),
    )
    forecast_data_values = PSY.get_cost.(TimeSeries.values(forecast_data)) .* base_power
    reserve_variable = get_variable(container, U(), T, PSY.get_name(service))
    component_name = PSY.get_name(component)
    for t in time_steps
        add_to_objective_invariant_expression!(
            container,
            forecast_data_values[t] * reserve_variable[component_name, t],
        )
    end
end

function _add_service_bid_cost!(::OptimizationContainer, ::PSY.Component, ::PSY.Service) end

function _add_service_bid_cost!(
    ::OptimizationContainer,
    ::PSY.Component,
    service::PSY.ReserveDemandCurve{T},
) where {T <: PSY.ReserveDirection}
    error(
        "The Current version doesn't supports cost bid for ReserveDemandCurve services, \\
        please change the forecast data for $(PSY.get_name(service)) \\
        and open a feature request",
    )
    return
end

"""
Adds to the cost function cost terms for sum of variables with common factor to be used for cost expression for optimization_container model.

# Arguments

  - container::OptimizationContainer : the optimization_container model built in PowerSimulations
  - var_key::VariableKey: The variable name
  - component_name::String: The component_name of the variable container
  - cost_component::PSY.VariableCost{Float64} : container for cost to be associated with variable
"""
function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_component::PSY.VariableCost{Float64},
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(T(), U())
    base_power = get_base_power(container)
    cost_data = PSY.get_cost(cost_component)
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    for time_period in get_time_steps(container)
        linear_cost = _add_proportional_term!(
            container,
            T(),
            component,
            cost_data * multiplier * base_power * dt,
            time_period,
        )
        add_to_expression!(
            container,
            ProductionCostExpression,
            linear_cost,
            component,
            time_period,
        )
    end
    return
end

@doc raw"""
Adds to the cost function cost terms for sum of variables with common factor to be used for cost expression for optimization_container model.

# Equation

``` gen_cost = dt*sign*(sum(variable.^2)*cost_data[1] + sum(variable)*cost_data[2]) ```

# LaTeX

`` cost = dt\times sign (sum_{i\in I} c_1 v_i^2 + sum_{i\in I} c_2 v_i ) ``

for quadratic factor large enough. If the first term of the quadratic objective is 0.0, adds a
linear cost term `sum(variable)*cost_data[2]`

# Arguments

* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* var_key::VariableKey: The variable name
* component_name::String: The component_name of the variable container
* cost_component::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
"""
function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_component::PSY.VariableCost{NTuple{2, Float64}},
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(T(), U())
    base_power = get_base_power(container)
    cost_data = PSY.get_cost(cost_component)
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    for time_period in get_time_steps(container)
        if cost_data[1] >= eps()
            cost_term = _add_quadratic_term!(
                container,
                T(),
                component,
                cost_data,
                base_power,
                multiplier * dt,
                time_period,
            )
        else
            cost_term = _add_proportional_term!(
                container,
                T(),
                component,
                cost_data[2] * multiplier * base_power * dt,
                time_period,
            )
        end
        add_to_expression!(
            container,
            ProductionCostExpression,
            cost_term,
            component,
            time_period,
        )
    end
    return
end

"""
Creates piecewise linear cost function using a sum of variables and expression with sign and time step included.

# Arguments

  - container::OptimizationContainer : the optimization_container model built in PowerSimulations
  - var_key::VariableKey: The variable name
  - component_name::String: The component_name of the variable container
  - cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}}
"""
function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}},
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    component_name = PSY.get_name(component)
    @debug "PWL Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    # If array is full of tuples with zeros return 0.0
    cost_data = PSY.get_cost(cost_component)
    if all(iszero.(last.(cost_data)))
        @debug "All cost terms for component $(component_name) are 0.0" _group =
            LOG_GROUP_COST_FUNCTIONS
        return
    end
    pwl_cost_expressions = _add_pwl_term!(container, component, cost_data, T(), U())
    for t in get_time_steps(container)
        add_to_expression!(
            container,
            ProductionCostExpression,
            pwl_cost_expressions[t],
            component,
            t,
        )
        add_to_objective_invariant_expression!(container, pwl_cost_expressions[t])
    end
    return
end

"""
Returns True/False depending on compatibility of the cost data with the convex implementation method
"""
function _slope_convexity_check(slopes::Vector{Float64})
    flag = true
    for ix in 1:(length(slopes) - 1)
        if slopes[ix] > slopes[ix + 1]
            @debug slopes _group = LOG_GROUP_COST_FUNCTIONS
            return flag = false
        end
    end
    return flag
end

function _check_pwl_compact_data(
    min::Float64,
    max::Float64,
    data::Vector{Tuple{Float64, Float64}},
    base_power::Float64,
)
    return isapprox(max - min, data[end][2] / base_power) && iszero(data[1][2])
end

function _check_pwl_compact_data(
    d::PSY.Component,
    data::Vector{Tuple{Float64, Float64}},
    base_power::Float64,
)
    min = PSY.get_active_power_limits(d).min
    max = PSY.get_active_power_limits(d).max
    return _check_pwl_compact_data(min, max, data, base_power)
end

function _get_sos_value(
    container::OptimizationContainer,
    ::Type{V},
    component::T,
) where {T <: PSY.Component, V <: AbstractDeviceFormulation}
    if has_container_key(container, OnStatusParameter, T)
        sos_val = SOSStatusVariable.PARAMETER
    else
        sos_val = sos_status(component, V())
    end
    return sos_val
end

function _get_sos_value(
    container::OptimizationContainer,
    ::Type{V},
    component::T,
) where {T <: PSY.Component, V <: AbstractServiceFormulation}
    return SOSStatusVariable.NO_VARIABLE
end

function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    cost_data::Vector{PSY.VariableCost{Float64}},
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    base_power = get_base_power(container)
    # Re-scale breakpoints by Basepower
    time_steps = get_time_steps(container)
    cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    for t in time_steps
        proportial_value = PSY.get_cost(cost_data[t]) * multiplier * base_power * dt
        cost_expressions[t] =
            _add_proportional_term!(container, U(), component, proportial_value, t)
    end
    return cost_expressions
end

"""
Add PWL cost terms for data coming from the MarketBidCost
"""
function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    cost_data::Vector{PSY.VariableCost{Vector{Tuple{Float64, Float64}}}},
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    base_power = get_base_power(container)
    # Re-scale breakpoints by Basepower
    name = PSY.get_name(component)
    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    sos_val = _get_sos_value(container, V, component)
    for t in time_steps
        data = PSY.get_cost(cost_data[t])
        is_power_data_compact = _check_pwl_compact_data(component, data, base_power)
        if !uses_compact_power(component, V()) && is_power_data_compact
            error(
                "The data provided is not compatible with formulation $V. Use a formulation compatible with Compact Cost Functions",
            )
            # data = _convert_to_full_variable_cost(data, component)
        elseif uses_compact_power(component, V()) && !is_power_data_compact
            data = _convert_to_compact_variable_cost(data)
        else
            @debug uses_compact_power(component, V()) name T V
            @debug is_power_data_compact name T V
        end
        slopes = PSY.get_slopes(data)
        # First element of the return is the average cost at P_min.
        # Shouldn't be passed for convexity check
        is_convex = _slope_convexity_check(slopes[2:end])
        break_points = map(x -> last(x), data) ./ base_power
        _add_pwl_variables!(container, T, name, t, data)
        _add_pwl_constraint!(container, component, U(), break_points, sos_val, t)
        if !is_convex
            _add_pwl_sos_constraint!(container, component, U(), break_points, sos_val, t)
        end
        pwl_cost = _get_pwl_cost_expression(container, component, t, data, multiplier * dt)
        pwl_cost_expressions[t] = pwl_cost
    end
    return pwl_cost_expressions
end

function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    cost_data::Vector{PSY.VariableCost{Vector{Tuple{Float64, Float64}}}},
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractServiceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    base_power = get_base_power(container)
    # Re-scale breakpoints by Basepower
    name = PSY.get_name(component)
    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    sos_val = _get_sos_value(container, V, component)
    for t in time_steps
        data = PSY.get_cost(cost_data[t])
        slopes = PSY.get_slopes(data)
        # Shouldn't be passed for convexity check
        is_convex = false
        break_points = map(x -> last(x), data) ./ base_power
        _add_pwl_variables!(container, T, name, t, data)
        _add_pwl_constraint!(container, component, U(), break_points, sos_val, t)
        if !is_convex
            _add_pwl_sos_constraint!(container, component, U(), break_points, sos_val, t)
        end
        pwl_cost = _get_pwl_cost_expression(container, component, t, data, multiplier * dt)
        pwl_cost_expressions[t] = pwl_cost
    end
    return pwl_cost_expressions
end

"""
Add PWL cost terms for data coming from a constant PWL cost function
"""
function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    data::Vector{NTuple{2, Float64}},
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    base_power = get_base_power(container)
    # Re-scale breakpoints by Basepower
    name = PSY.get_name(component)

    is_power_data_compact = _check_pwl_compact_data(component, data, base_power)

    if !uses_compact_power(component, V()) && is_power_data_compact
        error(
            "The data provided is not compatible with formulation $V. Use a formulation compatible with Compact Cost Functions",
        )
        # data = _convert_to_full_variable_cost(data, component)
    elseif uses_compact_power(component, V()) && !is_power_data_compact
        data = _convert_to_compact_variable_cost(data)
    else
        @debug uses_compact_power(component, V()) name T V
        @debug is_power_data_compact name T V
    end

    slopes = PSY.get_slopes(data)
    # First element of the return is the average cost at P_min.
    # Shouldn't be passed for convexity check
    is_convex = _slope_convexity_check(slopes[2:end])
    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    break_points = map(x -> last(x), data) ./ base_power
    sos_val = _get_sos_value(container, V, component)
    for t in time_steps
        _add_pwl_variables!(container, T, name, t, data)
        _add_pwl_constraint!(container, component, U(), break_points, sos_val, t)
        if !is_convex
            _add_pwl_sos_constraint!(container, component, U(), break_points, sos_val, t)
        end
        pwl_cost = _get_pwl_cost_expression(container, component, t, data, multiplier * dt)
        pwl_cost_expressions[t] = pwl_cost
    end
    return pwl_cost_expressions
end

function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    data::Vector{NTuple{2, Float64}},
    ::U,
    ::V,
) where {T <: PSY.ThermalGen, U <: VariableType, V <: ThermalDispatchNoMin}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    component_name = PSY.get_name(component)
    @debug "PWL cost function detected for device $(component_name) using $V"
    base_power = get_base_power(container)
    slopes = PSY.get_slopes(data)
    if any(slopes .< 0) || !_slope_convexity_check(slopes[2:end])
        throw(
            IS.InvalidValue(
                "The PWL cost data provided for generator $(component_name) is not compatible with $U.",
            ),
        )
    end

    if _check_pwl_compact_data(component, data, base_power)
        error("The data provided is not compatible with formulation $V. \\
              Use a formulation compatible with Compact Cost Functions")
    end

    if slopes[1] != 0.0
        @debug "PWL has no 0.0 intercept for generator $(component_name)"
        # adds a first intercept a x = 0.0 and Y below the intercept of the first tuple to make convex equivalent
        first_pair = data[1]
        intercept_point = (0.0, first_pair[2] - COST_EPSILON)
        data = vcat(intercept_point, data)
        @assert _slope_convexity_check(slopes)
    end

    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    break_points = map(x -> last(x), data) ./ base_power
    sos_val = _get_sos_value(container, V, component)
    for t in time_steps
        _add_pwl_variables!(container, T, component_name, t, data)
        _add_pwl_constraint!(container, component, U(), break_points, sos_val, t)
        pwl_cost = _get_pwl_cost_expression(container, component, t, data, multiplier * dt)
        pwl_cost_expressions[t] = pwl_cost
    end
    return pwl_cost_expressions
end

function _add_pwl_variables!(
    container::OptimizationContainer,
    ::Type{T},
    component_name::String,
    time_period::Int,
    cost_data::Vector{NTuple{2, Float64}},
) where {T <: PSY.Component}
    var_container = lazy_container_addition!(container, PieceWiseLinearCostVariable(), T)
    pwlvars = Array{JuMP.VariableRef}(undef, length(cost_data))
    for i in 1:length(cost_data)
        pwlvars[i] =
            var_container[(component_name, i, time_period)] = JuMP.@variable(
                get_jump_model(container),
                base_name = "PieceWiseLinearCostVariable_$(component_name)_{pwl_$(i), $time_period}",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
    end
    return pwlvars
end

function _add_pwl_constraint!(
    container::OptimizationContainer,
    component::T,
    ::U,
    break_points::Vector{Float64},
    sos_status::SOSStatusVariable,
    period::Int,
) where {T <: PSY.Component, U <: VariableType}
    variables = get_variable(container, U(), T)
    const_container = lazy_container_addition!(
        container,
        PieceWiseLinearCostConstraint(),
        T,
        axes(variables)...,
    )
    len_cost_data = length(break_points)
    jump_model = get_jump_model(container)
    pwl_vars = get_variable(container, PieceWiseLinearCostVariable(), T)
    name = PSY.get_name(component)
    const_container[name, period] = JuMP.@constraint(
        jump_model,
        variables[name, period] ==
        sum(pwl_vars[name, ix, period] * break_points[ix] for ix in 1:len_cost_data)
    )

    if sos_status == SOSStatusVariable.NO_VARIABLE
        bin = 1.0
        @debug "Using Piecewise Linear cost function but no variable/parameter ref for ON status is passed. Default status will be set to online (1.0)" _group =
            LOG_GROUP_COST_FUNCTIONS

    elseif sos_status == SOSStatusVariable.PARAMETER
        bin = get_parameter(container, OnStatusParameter(), T).parameter_array[name, period]
        @debug "Using Piecewise Linear cost function with parameter OnStatusParameter, $T" _group =
            LOG_GROUP_COST_FUNCTIONS
    elseif sos_status == SOSStatusVariable.VARIABLE
        bin = get_variable(container, OnVariable(), T)[name, period]
        @debug "Using Piecewise Linear cost function with variable OnVariable $T" _group =
            LOG_GROUP_COST_FUNCTIONS
    else
        @assert false
    end

    JuMP.@constraint(
        jump_model,
        sum(pwl_vars[name, i, period] for i in 1:len_cost_data) == bin
    )
    return
end

function _add_pwl_sos_constraint!(
    container::OptimizationContainer,
    component::T,
    ::U,
    break_points::Vector{Float64},
    sos_status::SOSStatusVariable,
    period::Int,
) where {T <: PSY.Component, U <: VariableType}
    name = PSY.get_name(component)
    @warn(
        "The cost function provided for $(name) is not compatible with a linear PWL cost function.
  An SOS-2 formulation will be added to the model. This will result in additional binary variables."
    )

    jump_model = get_jump_model(container)
    pwl_vars = get_variable(container, PieceWiseLinearCostVariable(), T)
    bp_count = length(break_points)
    pwl_vars_subset = [pwl_vars[name, i, period] for i in 1:bp_count]
    JuMP.@constraint(jump_model, pwl_vars_subset in MOI.SOS2(collect(1:bp_count)))
    return
end

function _get_pwl_cost_expression(
    container::OptimizationContainer,
    component::T,
    time_period::Int,
    cost_data::Vector{NTuple{2, Float64}},
    multiplier::Float64,
) where {T <: PSY.Component}
    name = PSY.get_name(component)
    pwl_var_container = get_variable(container, PieceWiseLinearCostVariable(), T)
    gen_cost = JuMP.AffExpr(0.0)
    slopes = PSY.get_slopes(cost_data)
    upb = PSY.get_breakpoint_upperbounds(cost_data)
    for i in 1:length(cost_data)
        JuMP.add_to_expression!(
            gen_cost,
            cost_data[i][1] * multiplier * pwl_var_container[(name, i, time_period)],
        )
    end
    return gen_cost
end

function _get_no_load_cost(
    component::T,
    ::V,
    ::U,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    return no_load_cost(PSY.get_operation_cost(component), U(), component, V())
end

function _convert_to_compact_variable_cost(
    var_cost::Vector{NTuple{2, Float64}},
    no_load_cost::Float64,
    p_min::Float64,
)
    return [(c - no_load_cost, pp - p_min) for (c, pp) in var_cost]
end

function _convert_to_compact_variable_cost(var_cost::Vector{NTuple{2, Float64}})
    no_load_cost, p_min = var_cost[1]
    return _convert_to_compact_variable_cost(var_cost, no_load_cost, p_min)
end

function _add_proportional_term!(
    container::OptimizationContainer,
    ::T,
    component::U,
    linear_term::Float64,
    time_period::Int,
) where {T <: VariableType, U <: PSY.Component}
    component_name = PSY.get_name(component)
    @debug "Linear Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    variable = get_variable(container, T(), U)[component_name, time_period]
    lin_cost = variable * linear_term
    add_to_objective_invariant_expression!(container, lin_cost)
    return lin_cost
end

function _add_quadratic_term!(
    container::OptimizationContainer,
    ::T,
    component::U,
    q_terms::NTuple{2, Float64},
    var_multiplier::Float64,
    expression_multiplier::Float64,
    time_period::Int,
) where {T <: VariableType, U <: PSY.Component}
    component_name = PSY.get_name(component)
    @debug "$component_name Quadratic Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    var = get_variable(container, T(), U)[component_name, time_period]
    q_cost_ = (var * var_multiplier) .^ 2 * q_terms[1] + var * var_multiplier * q_terms[2]
    q_cost = q_cost_ * expression_multiplier
    add_to_objective_invariant_expression!(container, q_cost)
    return q_cost
end

function _add_quadratic_term!(
    container::OptimizationContainer,
    ::T,
    component::U,
    q_terms::NTuple{2, Float64},
    var_multiplier::Float64,
    expression_multiplier::Float64,
    time_period::Int,
) where {T <: PowerAboveMinimumVariable, U <: PSY.ThermalGen}
    component_name = PSY.get_name(component)
    p_min = PSY.get_active_power_limits(component).min
    @debug "$component_name Quadratic Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    var = get_variable(container, T(), U)[component_name, time_period]
    q_cost_ =
        (var * var_multiplier) .^ 2 * q_terms[1] +
        var * var_multiplier * (q_terms[2] + 2 * q_terms[1] * p_min)
    q_cost = q_cost_ * expression_multiplier
    add_to_objective_invariant_expression!(container, q_cost)
    return q_cost
end
