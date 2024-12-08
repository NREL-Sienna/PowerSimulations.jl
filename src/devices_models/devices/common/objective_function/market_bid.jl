##################################################
################# PWL Variables ##################
##################################################

# For Market Bid 
function _add_pwl_variables!(
    container::OptimizationContainer,
    ::Type{T},
    component_name::String,
    time_period::Int,
    cost_data::PSY.PiecewiseStepData,
) where {T <: PSY.Component}
    var_container = lazy_container_addition!(container, PieceWiseLinearBlockOffer(), T)
    # length(PiecewiseStepData) gets number of segments, here we want number of points
    break_points = PSY.get_x_coords(cost_data)
    pwlvars = Array{JuMP.VariableRef}(undef, length(break_points))
    for i in 1:(length(break_points) - 1)
        pwlvars[i] =
            var_container[(component_name, i, time_period)] = JuMP.@variable(
                get_jump_model(container),
                base_name = "PieceWiseLinearBlockOffer_$(component_name)_{pwl_$(i), $time_period}",
                lower_bound = 0.0,
            )
    end
    return pwlvars
end

##################################################
################# PWL Constraints ################
##################################################

"""
Implement the constraints for PWL Block Offer variables. That is:

```math
\\sum_{k\\in\\mathcal{K}} \\delta_{k,t} = p_t \\\\
\\sum_{k\\in\\mathcal{K}} \\delta_{k,t} <= P_{k+1,t}^{max} - P_{k,t}^{max}
```
"""
function _add_pwl_constraint!(
    container::OptimizationContainer,
    component::T,
    ::U,
    break_points::Vector{Float64},
    period::Int,
) where {T <: PSY.Component, U <: VariableType}
    variables = get_variable(container, U(), T)
    const_container = lazy_container_addition!(
        container,
        PieceWiseLinearBlockOfferConstraint(),
        T,
        axes(variables)...,
    )
    len_cost_data = length(break_points) - 1
    jump_model = get_jump_model(container)
    pwl_vars = get_variable(container, PieceWiseLinearBlockOffer(), T)
    name = PSY.get_name(component)
    const_container[name, period] = JuMP.@constraint(
        jump_model,
        variables[name, period] ==
        sum(pwl_vars[name, ix, period] for ix in 1:len_cost_data)
    )

    #=
    const_upperbound_container = lazy_container_addition!(
        container,
        PieceWiseLinearUpperBoundConstraint(),
        T,
        axes(pwl_vars)...;
    )
    =#

    # TODO: Parameter for this 
    for ix in 1:len_cost_data
        JuMP.@constraint(
            jump_model,
            pwl_vars[name, ix, period] <= break_points[ix + 1] - break_points[ix]
        )
    end
    return
end

"""
Implement the constraints for PWL Block Offer variables for ORDC. That is:

```math
\\sum_{k\\in\\mathcal{K}} \\delta_{k,t} = p_t \\\\
\\sum_{k\\in\\mathcal{K}} \\delta_{k,t} <= P_{k+1,t}^{max} - P_{k,t}^{max}
```
"""
function _add_pwl_constraint!(
    container::OptimizationContainer,
    component::T,
    ::U,
    break_points::Vector{Float64},
    sos_status::SOSStatusVariable,
    period::Int,
) where {T <: PSY.ReserveDemandCurve, U <: ServiceRequirementVariable}
    name = PSY.get_name(component)
    variables = get_variable(container, U(), T, name)
    const_container = lazy_container_addition!(
        container,
        PieceWiseLinearBlockOfferConstraint(),
        T,
        axes(variables)...;
        meta = name,
    )
    len_cost_data = length(break_points) - 1
    jump_model = get_jump_model(container)
    pwl_vars = get_variable(container, PieceWiseLinearBlockOffer(), T)
    const_container[name, period] = JuMP.@constraint(
        jump_model,
        variables[name, period] ==
        sum(pwl_vars[name, ix, period] for ix in 1:len_cost_data)
    )

    for ix in 1:len_cost_data
        JuMP.@constraint(
            jump_model,
            pwl_vars[name, ix, period] <= break_points[ix + 1] - break_points[ix]
        )
    end
    return
end

##################################################
################ PWL Expressions #################
##################################################

function _get_pwl_cost_expression(
    container::OptimizationContainer,
    component::T,
    time_period::Int,
    cost_data::PSY.PiecewiseStepData,
    multiplier::Float64,
) where {T <: PSY.Component}
    name = PSY.get_name(component)
    pwl_var_container = get_variable(container, PieceWiseLinearBlockOffer(), T)
    gen_cost = JuMP.AffExpr(0.0)
    cost_data = PSY.get_y_coords(cost_data)
    for (i, cost) in enumerate(cost_data)
        JuMP.add_to_expression!(
            gen_cost,
            cost * multiplier * pwl_var_container[(name, i, time_period)],
        )
    end
    return gen_cost
end

function _get_pwl_cost_expression(
    container::OptimizationContainer,
    component::T,
    time_period::Int,
    cost_function::PSY.MarketBidCost,
    ::PSY.PiecewiseStepData,
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    incremental_curve = PSY.get_incremental_offer_curves(cost_function)
    value_curve = PSY.get_value_curve(incremental_curve)
    power_units = PSY.get_power_units(incremental_curve)
    cost_component = PSY.get_function_data(value_curve)
    base_power = get_base_power(container)
    device_base_power = PSY.get_base_power(component)
    cost_data_normalized = get_piecewise_incrementalcurve_per_system_unit(
        cost_component,
        power_units,
        base_power,
        device_base_power,
    )
    resolution = get_resolution(container)
    dt = Dates.value(resolution) / MILLISECONDS_IN_HOUR
    return _get_pwl_cost_expression(
        container,
        component,
        time_period,
        cost_data_normalized,
        dt,
    )
end

"""
Get cost expression for StepwiseCostReserve
"""
function _get_pwl_cost_expression(
    container::OptimizationContainer,
    component::T,
    time_period::Int,
    cost_data::PSY.PiecewiseStepData,
    multiplier::Float64,
) where {T <: PSY.ReserveDemandCurve}
    name = PSY.get_name(component)
    pwl_var_container = get_variable(container, PieceWiseLinearBlockOffer(), T)
    slopes = PSY.get_y_coords(cost_data)
    ordc_cost = JuMP.AffExpr(0.0)
    for i in 1:length(slopes)
        JuMP.add_to_expression!(
            ordc_cost,
            slopes[i] * multiplier * pwl_var_container[(name, i, time_period)],
        )
    end
    return ordc_cost
end

#=
# For Market Bid 
function _add_pwl_variables!(
    container::OptimizationContainer,
    ::Type{T},
    component_name::String,
    time_period::Int,
    cost_data::PSY.PiecewiseStepData,
) where {T <: PSY.Component}
    var_container = lazy_container_addition!(container, PieceWiseLinearCostVariable(), T)
    # length(PiecewiseStepData) gets number of segments, here we want number of points
    pwlvars = Array{JuMP.VariableRef}(undef, length(cost_data) + 1)
    for i in 1:(length(cost_data) + 1)
        pwlvars[i] =
            var_container[(component_name, i, time_period)] = JuMP.@variable(
                get_jump_model(container),
                base_name = "PieceWiseLinearCostVariable_$(component_name)_{pwl_$(i), $time_period}",
            )
    end
    return pwlvars
end

# For Market Bid #
function _get_pwl_cost_expression(
    container::OptimizationContainer,
    component::T,
    time_period::Int,
    cost_data::PSY.PiecewiseStepData,
    multiplier::Float64,
) where {T <: PSY.Component}
    # TODO: This functions needs to be reimplemented for the new model. The code is repeated
    # because the internals will be different
    name = PSY.get_name(component)
    pwl_var_container = get_variable(container, PieceWiseLinearCostVariable(), T)
    gen_cost = JuMP.AffExpr(0.0)
    cost_data = PSY.get_y_coords(cost_data)
    for (i, cost) in enumerate(cost_data)
        JuMP.add_to_expression!(
            gen_cost,
            cost * multiplier * pwl_var_container[(name, i, time_period)],
        )
    end
    return gen_cost
end

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
=#

###############################################
######## MarketBidCost: Fixed Curves ##########
###############################################

"""
Add PWL cost terms for data coming from the MarketBidCost
with a fixed incremental offer curve
"""
function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    cost_function::PSY.MarketBidCost,
    ::PSY.CostCurve{PSY.PiecewiseIncrementalCurve},
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    name = PSY.get_name(component)
    incremental_offer_curve = PSY.get_incremental_offer_curves(cost_function)
    value_curve = PSY.get_value_curve(incremental_offer_curve)
    cost_component = PSY.get_function_data(value_curve)
    base_power = get_base_power(container)
    device_base_power = PSY.get_base_power(component)
    power_units = PSY.get_power_units(incremental_offer_curve)

    data = get_piecewise_incrementalcurve_per_system_unit(
        cost_component,
        power_units,
        base_power,
        device_base_power,
    )

    cost_is_convex = PSY.is_convex(data)
    if !cost_is_convex
        error("MarketBidCost for component $(name) is non-convex")
    end

    break_points = PSY.get_x_coords(data)
    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    for t in time_steps
        _add_pwl_variables!(container, T, name, t, data)
        _add_pwl_constraint!(container, component, U(), break_points, t)
        pwl_cost =
            _get_pwl_cost_expression(container, component, t, cost_function, data, U(), V())
        pwl_cost_expressions[t] = pwl_cost
    end
    return pwl_cost_expressions
end

##################################################
########## PWL for StepwiseCostReserve  ##########
##################################################

function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    cost_data::PSY.CostCurve{PSY.PiecewiseIncrementalCurve},
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractServiceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    base_power = get_base_power(container)
    value_curve = PSY.get_value_curve(cost_data)
    power_units = PSY.get_power_units(cost_data)
    cost_component = PSY.get_function_data(value_curve)
    device_base_power = PSY.get_base_power(component)
    data = get_piecewise_incrementalcurve_per_system_unit(
        cost_component,
        power_units,
        base_power,
        device_base_power,
    )
    name = PSY.get_name(component)
    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    sos_val = _get_sos_value(container, V, component)
    for t in time_steps
        break_points = PSY.get_x_coords(data)
        _add_pwl_variables!(container, T, name, t, data)
        _add_pwl_constraint!(container, component, U(), break_points, sos_val, t)
        pwl_cost = _get_pwl_cost_expression(container, component, t, data, multiplier * dt)
        pwl_cost_expressions[t] = pwl_cost
    end
    return pwl_cost_expressions
end

#=
"""
Add PWL cost terms for data coming from the MarketBidCost
with a timeseries incremental offer curve
"""
function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    cost_function::PSY.MarketBidCost,
    ::PSY.TimeSeriesKey,
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    name = PSY.get_name(component)
    value_curve = PSY.get_value_curve(incremental_offer_curve)
    cost_component = PSY.get_function_data(value_curve)
    base_power = get_base_power(container)
    device_base_power = PSY.get_base_power(component)
    power_units = PSY.get_power_units(cost_function)

    data = get_piecewise_incrementalcurve_per_system_unit(
        cost_component,
        power_units,
        base_power,
        device_base_power,
    )
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
=#
############################################################
######## MarketBidCost: PiecewiseIncrementalCurve ##########
############################################################

"""
Creates piecewise linear market bid function using a sum of variables and expression for market participants.
Decremental offers are not accepted for most components, except Storage systems and loads.

# Arguments

  - container::OptimizationContainer : the optimization_container model built in PowerSimulations
  - var_key::VariableKey: The variable name
  - component_name::String: The component_name of the variable container
  - cost_function::MarketBidCost : container for market bid cost
"""
function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_function::PSY.MarketBidCost,
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    component_name = PSY.get_name(component)
    @debug "Market Bid" _group = LOG_GROUP_COST_FUNCTIONS component_name
    time_steps = get_time_steps(container)
    initial_time = get_initial_time(container)
    incremental_cost_curves = PSY.get_incremental_offer_curves(cost_function)
    decremental_cost_curves = PSY.get_decremental_offer_curves(cost_function)
    # if isnothing(decremental_cost_curves)
    #     error("Component $(component_name) is not allowed to participate as a demand.")
    # end
    #=
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
    =#
    pwl_cost_expressions =
        _add_pwl_term!(
            container,
            component,
            cost_function,
            incremental_cost_curves,
            T(),
            U(),
        )
    jump_model = get_jump_model(container)
    for t in time_steps
        #=
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
        =#
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
    #=
    ancillary_services = PSY.get_ancillary_service_offers(op_cost)
    for service in ancillary_services
        _add_service_bid_cost!(container, component, service)
    end
    =#
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

function _add_vom_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    op_cost::PSY.MarketBidCost,
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    incremental_cost_curves = PSY.get_incremental_offer_curves(op_cost)
    decremental_cost_curves = PSY.get_decremental_offer_curves(op_cost)
    power_units = PSY.get_power_units(incremental_cost_curves)
    vom_cost = PSY.get_vom_cost(incremental_cost_curves)
    multiplier = 1.0 # VOM Cost is always positive
    cost_term = PSY.get_proportional_term(vom_cost)
    iszero(cost_term) && return
    base_power = get_base_power(container)
    device_base_power = PSY.get_base_power(component)
    cost_term_normalized = get_proportional_cost_per_system_unit(
        cost_term,
        power_units,
        base_power,
        device_base_power,
    )
    for t in get_time_steps(container)
        exp =
            _add_proportional_term!(container, T(), d, cost_term_normalized * multiplier, t)
        add_to_expression!(container, ProductionCostExpression, exp, d, t)
    end
    return
end
