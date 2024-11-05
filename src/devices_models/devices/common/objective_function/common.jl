##################################
#### ActivePowerVariable Cost ####
##################################

function add_variable_cost!(
    container::OptimizationContainer,
    ::U,
    devices::IS.FlattenIteratorWrapper{T},
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    for d in devices
        op_cost_data = PSY.get_operation_cost(d)
        _add_variable_cost_to_objective!(container, U(), d, op_cost_data, V())
        _add_vom_cost_to_objective!(container, U(), d, op_cost_data, V())
    end
    return
end

##################################
#### Start/Stop Variable Cost ####
##################################

function add_shut_down_cost!(
    container::OptimizationContainer,
    ::U,
    devices::IS.FlattenIteratorWrapper{T},
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    for d in devices
        PSY.get_must_run(d) && continue
        op_cost_data = PSY.get_operation_cost(d)
        cost_term = shut_down_cost(op_cost_data, d, V())
        iszero(cost_term) && continue
        for t in get_time_steps(container)
            _add_proportional_term!(container, U(), d, cost_term * multiplier, t)
        end
    end
    return
end

##################################
####### Proportional Cost ########
##################################
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
            exp = _add_proportional_term!(container, U(), d, cost_term * multiplier, t)
            add_to_expression!(container, ProductionCostExpression, exp, d, t)
        end
    end
    return
end

##################################
########## VOM Cost ##############
##################################

function _add_vom_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    op_cost::PSY.OperationalCost,
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    variable_cost_data = variable_cost(op_cost, T(), component, U())
    power_units = PSY.get_power_units(variable_cost_data)
    vom_cost = PSY.get_vom_cost(variable_cost_data)
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

##################################
######## OnVariable Cost #########
##################################

function add_proportional_cost!(
    container::OptimizationContainer,
    ::U,
    devices::IS.FlattenIteratorWrapper{T},
    ::V,
) where {T <: PSY.ThermalGen, U <: OnVariable, V <: AbstractThermalUnitCommitment}
    multiplier = objective_function_multiplier(U(), V())
    for d in devices
        op_cost_data = PSY.get_operation_cost(d)
        for t in get_time_steps(container)
            cost_term = proportional_cost(container, op_cost_data, U(), d, V(), t)
            iszero(cost_term) && continue
            if !PSY.get_must_run(d)
                exp = _add_proportional_term!(container, U(), d, cost_term * multiplier, t)
                add_to_expression!(container, ProductionCostExpression, exp, d, t)
            end
            add_to_expression!(
                container,
                ProductionCostExpression,
                cost_term * multiplier,
                d,
                t,
            )
        end
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
    component::PSY.ThermalGen,
    op_cost::Union{PSY.ThermalGenerationCost, PSY.MarketBidCost},
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    PSY.get_must_run(component) && return
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
    component::PSY.ThermalMultiStart,
    op_cost::PSY.ThermalGenerationCost,
    ::U,
) where {T <: VariableType, U <: ThermalMultiStartUnitCommitment}
    PSY.get_must_run(component) && return
    cost_terms = start_up_cost(op_cost, component, U())
    cost_term = cost_terms[MULTI_START_COST_MAP[T]]
    iszero(cost_term) && return
    multiplier = objective_function_multiplier(T(), U())
    for t in get_time_steps(container)
        _add_proportional_term!(container, T(), component, cost_term * multiplier, t)
    end
    return
end

function _get_cost_function_parameter_container(
    container::OptimizationContainer,
    ::S,
    component::T,
    ::U,
    ::V,
    cost_type::Type{W},
) where {
    S <: ObjectiveFunctionParameter,
    T <: PSY.Component,
    U <: VariableType,
    V <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    W,
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
            U,
            sos_val,
            uses_compact_power(component, V()),
            W,
            container_axes...,
        )
    end
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
    expression_multiplier::Float64,
    time_period::Int,
) where {T <: VariableType, U <: PSY.Component}
    component_name = PSY.get_name(component)
    @debug "$component_name Quadratic Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    var = get_variable(container, T(), U)[component_name, time_period]
    q_cost_ = var .^ 2 * q_terms[1] + var * q_terms[2]
    q_cost = q_cost_ * expression_multiplier
    add_to_objective_invariant_expression!(container, q_cost)
    return q_cost
end

##################################################
################## Fuel Cost #####################
##################################################

function _get_fuel_cost_value(
    container::OptimizationContainer,
    component::T,
    time_period::Int,
) where {T <: PSY.Component}
    # TODO: Check time series for derating to work later
    if PSY.has_time_series(component)
        parameter_array = get_parameter_array(container, FuelCostParameter(), T)
        parameter_multiplier =
            get_parameter_multiplier_array(container, FuelCostParameter(), T)
        name = PSY.get_name(component)
        return parameter_array[name, time_period] * parameter_multiplier[name, time_period]
    else
        return PSY.get_fuel_cost(component)
    end
end

function _add_time_varying_fuel_variable_cost!(
    container::OptimizationContainer,
    ::T,
    component::V,
    fuel_cost::IS.TimeSeriesKey,
) where {T <: VariableType, V <: PSY.Component}
    parameter = get_parameter_array(container, FuelCostParameter(), V)
    multiplier = get_parameter_multiplier_array(container, FuelCostParameter(), V)
    expression = get_expression(container, FuelConsumptionExpression(), V)
    name = PSY.get_name(component)
    for t in get_time_steps(container)
        cost_expr = expression[name, t] * parameter[name, t] * multiplier[name, t]
        add_to_expression!(
            container,
            ProductionCostExpression,
            cost_expr,
            component,
            t,
        )
        add_to_objective_variant_expression!(container, cost_expr)
    end
    return
end
