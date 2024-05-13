##################################################
################# MarketBidCost ##################
##################################################

function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    cost_data::AbstractVector{PSY.LinearFunctionData},
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(resolution) / MILLISECONDS_IN_HOUR
    base_power = get_base_power(container)
    # Re-scale breakpoints by Basepower
    time_steps = get_time_steps(container)
    cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    for t in time_steps
        proportional_value =
            PSY.get_proportional_term(cost_data[t]) * multiplier * base_power * dt
        cost_expressions[t] =
            _add_proportional_term!(container, U(), component, proportional_value, t)
    end
    return cost_expressions
end

"""
Add PWL cost terms for data coming from the MarketBidCost
"""
function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    cost_data::AbstractVector{PSY.PiecewiseStepData},
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(resolution) / MILLISECONDS_IN_HOUR
    base_power = get_base_power(container)
    # Re-scale breakpoints by Basepower
    name = PSY.get_name(component)
    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    sos_val = _get_sos_value(container, V, component)
    for t in time_steps
        # Run checks in every time step because each time step has a PWL cost function
        data = cost_data[t]
        compact_status = validate_compact_pwl_data(component, data, base_power)
        if !uses_compact_power(component, V()) && compact_status == COMPACT_PWL_STATUS.VALID
            error(
                "The data provided is not compatible with formulation $V. Use a formulation compatible with Compact Cost Functions",
            )
            # data = _convert_to_full_variable_cost(data, component)
        elseif uses_compact_power(component, V()) &&
               compact_status != COMPACT_PWL_STATUS.VALID
            @warn(
                "The cost data provided is not in compact form. Will attempt to convert. Errors may occur."
            )
            data = convert_to_compact_variable_cost(data)
        else
            @debug uses_compact_power(component, V()) compact_status name T V
        end
        cost_is_convex = PSY.is_convex(data)
        break_points = PSY.get_x_coords(data) ./ base_power  # TODO should this be get_x_lengths/get_breakpoint_upper_bounds?
        _add_pwl_variables!(container, T, name, t, data)
        _add_pwl_constraint!(container, component, U(), break_points, sos_val, t)
        if !cost_is_convex
            _add_pwl_sos_constraint!(container, component, U(), break_points, sos_val, t)
        end
        pwl_cost =
            _get_pwl_cost_expression(container, component, t, data, multiplier * dt)
        pwl_cost_expressions[t] = pwl_cost
    end
    return pwl_cost_expressions
end

function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    cost_data::AbstractVector{PSY.PiecewiseStepData},
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractServiceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(resolution) / MILLISECONDS_IN_HOUR
    base_power = get_base_power(container)
    # Re-scale breakpoints by Basepower
    name = PSY.get_name(component)
    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    sos_val = _get_sos_value(container, V, component)
    for t in time_steps
        data = cost_data[t]
        break_points = PSY.get_x_coords(data) ./ base_power
        _add_pwl_variables!(container, T, name, t, data)
        _add_pwl_constraint!(container, component, U(), break_points, sos_val, t)
        _add_pwl_sos_constraint!(container, component, U(), break_points, sos_val, t)
        pwl_cost = _get_pwl_cost_expression(container, component, t, data, multiplier * dt)
        pwl_cost_expressions[t] = pwl_cost
    end
    return pwl_cost_expressions
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
        start_time = initial_time,
        len = length(time_steps),
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
        set_multiplier!(
            parameter_container,
            # Using 1.0 here since we want to reuse the existing code that adds the mulitpler
            #  of base power times the time delta.
            1.0,
            component_name,
            t,
        )
        set_parameter!(
            parameter_container,
            jump_model,
            variable_cost_forecast_values[t],
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
    ancillary_services = PSY.get_ancillary_service_offers(op_cost)
    for service in ancillary_services
        _add_service_bid_cost!(container, component, service)
    end
    return
end

function _add_service_bid_cost!(
    container::OptimizationContainer,
    component::PSY.Component,
    service::T,
) where {T <: PSY.Reserve{<:PSY.ReserveDirection}}
    time_steps = get_time_steps(container)
    initial_time = get_initial_time(container)
    base_power = get_base_power(container)
    forecast_data = PSY.get_services_bid(
        component,
        PSY.get_operation_cost(component),
        service;
        start_time = initial_time,
        len = length(time_steps),
    )
    forecast_data_values = PSY.get_cost.(TimeSeries.values(forecast_data))
    # Single Price Bid
    if eltype(forecast_data_values) == Float64
        data_values = forecast_data_values
        # Single Price/Quantity Bid
    elseif eltype(forecast_data_values) == Vector{NTuple{2, Float64}}
        data_values = [v[1][1] for v in forecast_data_values]
    else
        error("$(eltype(forecast_data_values)) not supported for MarketBidCost")
    end

    reserve_variable =
        get_variable(container, ActivePowerReserveVariable(), T, PSY.get_name(service))
    component_name = PSY.get_name(component)
    for t in time_steps
        add_to_objective_invariant_expression!(
            container,
            data_values[t] * base_power * reserve_variable[component_name, t],
        )
    end
    return
end

function _add_service_bid_cost!(::OptimizationContainer, ::PSY.Component, ::PSY.Service) end
