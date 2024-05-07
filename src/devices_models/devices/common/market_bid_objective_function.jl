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
