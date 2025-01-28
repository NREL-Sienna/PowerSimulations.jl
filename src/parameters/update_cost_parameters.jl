function _update_parameter_values!(
    parameter_array::DenseAxisArray,
    parameter_multiplier::JuMPFloatArray,
    attributes::CostFunctionAttributes,
    ::Type{V},
    model::DecisionModel,
    ::DatasetContainer{InMemoryDataset},
) where {V <: PSY.Component}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    time_steps = get_time_steps(get_optimization_container(model))
    horizon = time_steps[end]
    container = get_optimization_container(model)
    @assert !is_synchronized(container)
    template = get_template(model)
    device_model = get_model(template, V)
    components = get_available_components(device_model, get_system(model))
    for component in components
        if _has_variable_cost_parameter(component)
            name = PSY.get_name(component)
            op_cost = PSY.get_operation_cost(component)
            if op_cost isa PSY.MarketBidCost
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
            elseif op_cost isa PSY.ThermalGenerationCost
                fuel_curve = PSY.get_variable(op_cost)
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
            else
                error(
                    "Update Cost Function Parameter not implemented for $(typeof(op_cost))",
                )
            end
        end
    end
    return
end

_has_variable_cost_parameter(component::PSY.Component) =
    _has_variable_cost_parameter(PSY.get_operation_cost(component))
_has_variable_cost_parameter(::PSY.MarketBidCost) = true
_has_variable_cost_parameter(::T) where {T <: PSY.OperationalCost} = false
function _has_variable_cost_parameter(cost::T) where {T <: PSY.ThermalGenerationCost}
    var_cost = PSY.get_variable(cost)
    if var_cost isa PSY.FuelCurve
        if PSY.get_fuel_cost(var_cost) isa IS.TimeSeriesKey
            return true
        end
    end
    return false
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

function update_variable_cost!(
    container::OptimizationContainer,
    parameter_array::JuMPFloatArray,
    parameter_multiplier::JuMPFloatArray,
    attributes::CostFunctionAttributes{Float64},
    component::T,
    time_period::Int,
) where {T <: PSY.Component}
    resolution = get_resolution(container)
    dt = Dates.value(resolution) / MILLISECONDS_IN_HOUR
    base_power = get_base_power(container)
    component_name = PSY.get_name(component)
    cost_data = parameter_array[component_name, time_period]  # TODO is this a new-style cost?
    if iszero(cost_data)
        return
    end
    mult_ = parameter_multiplier[component_name, time_period]
    variable = get_variable(container, get_variable_type(attributes)(), T)
    gen_cost = variable[component_name, time_period] * (mult_ * cost_data * base_power * dt)
    add_to_objective_variant_expression!(container, gen_cost)
    set_expression!(container, ProductionCostExpression, gen_cost, component, time_period)
    return
end

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
    # TODO: missing _mult below?
    set_expression!(container, ProductionCostExpression, gen_cost, component, time_period)
    return
end

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
    cost_expr = expression[component_name, time_period] * (fuel_cost * mult_)
    add_to_objective_variant_expression!(container, cost_expr)
    # TODO: missing _mult below?
    set_expression!(container, ProductionCostExpression, cost_expr, component, time_period)
    return
end
