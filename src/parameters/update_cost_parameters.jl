function _update_parameter_values!(
    ::T,
    parameter_array::DenseAxisArray,
    parameter_multiplier::JuMPFloatArray,
    attributes::CostFunctionAttributes,
    ::Type{V},
    model::DecisionModel,
    ::DatasetContainer{InMemoryDataset},
) where {T <: ObjectiveFunctionParameter, V <: PSY.Component}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    time_steps = get_time_steps(get_optimization_container(model))
    horizon = time_steps[end]
    container = get_optimization_container(model)
    @assert !is_synchronized(container)
    template = get_template(model)
    device_model = get_model(template, V)
    components = get_available_components(device_model, get_system(model))
    for component in components
        name = PSY.get_name(component)
        op_cost = PSY.get_operation_cost(component)
        # `handle_variable_cost_parameter` is responsible for figuring out whether there is
        # actually time variance for this particular component and, if so, performing the update
        handle_variable_cost_parameter(
            T(),
            op_cost,
            component,
            name,
            parameter_array,
            parameter_multiplier,
            attributes,
            container,
            initial_forecast_time,
            horizon,
        )
    end
    return
end

# TODO storing this old code here for now, it is currently unreachable
# This is implicated in the MarketBidCost time varying incremental/decremental implementation, which will be addressed later
function handle_variable_cost_parameter(::Tuple{}, args...)
    ts_vector = PSY.get_variable_cost(
        component,
        PSY.get_operation_cost(component);
        start_time = initial_forecast_time,
        len = horizon,
    )
    variable_cost_forecast_values = TimeSeries.values(ts_vector)
    for (t, value) in enumerate(variable_cost_forecast_values)
        if attributes.uses_compact_power
            # TODO implement this
            value, _ = _convert_variable_cost(value)
        end
        # TODO removed an apparently unused block of code here?
        _set_param_value!(parameter_array, value, name, t)
        update_variable_cost!(
            container,
            parameter_array,
            parameter_multiplier,
            attributes,
            component,
            t,
        )
    end
end

# No-op for everything but MarketBidCost
handle_variable_cost_parameter(
    ::StartupCostParameter,
    op_cost::PSY.OperationalCost, args...) = nothing
handle_variable_cost_parameter(
    ::ShutdownCostParameter,
    op_cost::PSY.OperationalCost, args...) = nothing

function handle_variable_cost_parameter(
    ::StartupCostParameter,
    op_cost::PSY.MarketBidCost,
    component,
    name,
    parameter_array,
    parameter_multiplier,
    attributes,
    container,
    initial_forecast_time,
    horizon,
)
    is_time_variant(PSY.get_start_up(op_cost)) || return
    ts_vector = PSY.get_start_up(
        component, op_cost;
        start_time = initial_forecast_time,
        len = horizon,
    )
    for (t, value) in enumerate(TimeSeries.values(ts_vector))
        _set_param_value!(parameter_array, Tuple(value), name, t)
        update_variable_cost!(
            container,
            parameter_array,
            parameter_multiplier,
            attributes,
            component,
            t,
        )
    end
end

function handle_variable_cost_parameter(::ShutdownCostParameter, args...)
    @warn "Not yet implemented"
end

function handle_variable_cost_parameter(
    ::FuelCostParameter,
    op_cost::PSY.ThermalGenerationCost,
    component,
    name,
    parameter_array,
    parameter_multiplier,
    attributes,
    container,
    initial_forecast_time,
    horizon,
)
    fuel_curve = PSY.get_variable(op_cost)
    # Nothing to update for this component if we don't have a fuel cost time series
    (fuel_curve isa PSY.FuelCurve && is_time_variant(PSY.get_fuel_cost(fuel_curve))) ||
        return

    ts_vector = PSY.get_fuel_cost(
        component;
        start_time = initial_forecast_time,
        len = horizon,
    )
    fuel_cost_forecast_values = TimeSeries.values(ts_vector)
    for (t, value) in enumerate(fuel_cost_forecast_values)
        # TODO: Is this compact power attribute being used?
        if attributes.uses_compact_power
            # TODO implement this
            value, _ = _convert_variable_cost(value)
        end
        _set_param_value!(parameter_array, value, name, t)
        update_variable_cost!(
            container,
            parameter_array,
            parameter_multiplier,
            attributes,
            component,
            fuel_curve,
            t,
        )
    end
end

function _update_pwl_cost_expression(
    container::OptimizationContainer,
    ::Type{T},
    component_name::String,
    time_period::Int,
    cost_data::PSY.PiecewiseLinearData,
) where {T <: PSY.Component}
    pwl_var_container = get_variable(container, PieceWiseLinearCostVariable(), T)
    resolution = get_resolution(container)
    dt = Dates.value(resolution) / MILLISECONDS_IN_HOUR
    gen_cost = JuMP.AffExpr(0.0)
    slopes = PSY.get_slopes(cost_data)
    upb = get_breakpoint_upper_bounds(cost_data)
    for i in 1:length(cost_data)
        JuMP.add_to_expression!(
            gen_cost,
            slopes[i] * upb[i] * dt,
            pwl_var_container[(component_name, i, time_period)],
        )
    end
    return gen_cost
end

# General case
# (TODO this seemed rather decrepit before I got here and made big changes, make sure I didn't break anything)
function update_variable_cost!(
    container::OptimizationContainer,
    parameter_array::DenseAxisArray{T},
    parameter_multiplier::JuMPFloatArray,  # TODO is the multiplier always `JuMPFloatArray`?
    attributes::CostFunctionAttributes{T},
    component::U,
    time_period::Int,
) where {T, U <: PSY.Component}
    component_name = PSY.get_name(component)
    cost_data = parameter_array[component_name, time_period]
    # TODO is this really correct? If it's zero now we can just leave it, it won't keep the value from last round?
    # if iszero(cost_data)
    #     return
    # end
    mult_ = parameter_multiplier[component_name, time_period]
    for MyVariableType in get_variable_types(attributes)
        variable = get_variable(container, MyVariableType(), U)
        my_cost_data = start_up_cost(cost_data, MyVariableType())
        cost_expr = variable[component_name, time_period] * my_cost_data * mult_
        add_to_objective_variant_expression!(container, cost_expr)
        set_expression!(
            container,
            ProductionCostExpression,
            cost_expr,
            component,
            time_period,
        )
    end
end

# Special case for PiecewiseLinearData
function update_variable_cost!(
    container::OptimizationContainer,
    parameter_array::DenseAxisArray{Vector{NTuple{2, Float64}}},
    parameter_multiplier::JuMPFloatArray,
    ::CostFunctionAttributes{Vector{NTuple{2, Float64}}},
    component::T,
    time_period::Int,
) where {T <: PSY.Component}
    component_name = PSY.get_name(component)
    cost_data = parameter_array[component_name, time_period]
    if all(iszero.(last.(cost_data)))
        return
    end
    mult_ = parameter_multiplier[component_name, time_period]
    gen_cost =
        _update_pwl_cost_expression(
            container,
            T,
            component_name,
            time_period,
            PSY.PiecewiseLinearData(cost_data),
        )
    add_to_objective_variant_expression!(container, mult_ * gen_cost)
    set_expression!(container, ProductionCostExpression, gen_cost, component, time_period)
    return
end

# Special case for fuel cost
function update_variable_cost!(
    container::OptimizationContainer,
    parameter_array::JuMPFloatArray,
    parameter_multiplier::JuMPFloatArray,
    ::CostFunctionAttributes{Float64},
    component::T,
    fuel_curve::PSY.FuelCurve,
    time_period::Int,
) where {T <: PSY.Component}
    component_name = PSY.get_name(component)
    fuel_cost = parameter_array[component_name, time_period]
    if all(iszero.(last.(fuel_cost)))
        return
    end
    mult_ = parameter_multiplier[component_name, time_period]
    expression = get_expression(container, FuelConsumptionExpression(), T)
    cost_expr = expression[component_name, time_period] * fuel_cost * mult_
    add_to_objective_variant_expression!(container, cost_expr)
    set_expression!(container, ProductionCostExpression, cost_expr, component, time_period)
    return
end
