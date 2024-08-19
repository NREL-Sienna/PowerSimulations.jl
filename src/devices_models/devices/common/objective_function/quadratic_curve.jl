# Add proportional terms to objective function and expression
function _add_quadraticcurve_variable_term_to_model!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    proportional_term_per_unit::Float64,
    quadratic_term_per_unit::Float64,
    time_period::Int,
) where {T <: VariableType}
    resolution = get_resolution(container)
    dt = Dates.value(resolution) / MILLISECONDS_IN_HOUR
    if quadratic_term_per_unit >= eps()
        cost_term = _add_quadratic_term!(
            container,
            T(),
            component,
            (quadratic_term_per_unit, proportional_term_per_unit),
            dt,
            time_period,
        )
    else
        cost_term = _add_proportional_term!(
            container,
            T(),
            component,
            proportional_term_per_unit * dt,
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
    return
end

# Dispatch for vector proportional/quadratic terms
function _add_quadraticcurve_variable_cost!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    proportional_term_per_unit::Vector{Float64},
    quadratic_term_per_unit::Vector{Float64},
) where {T <: VariableType}
    for t in get_time_steps(container)
        _add_quadraticcurve_variable_term_to_model!(
            container,
            T(),
            component,
            proportional_term_per_unit[t],
            quadratic_term_per_unit[t],
            t,
        )
    end
    return
end

# Dispatch for scalar proportional/quadratic terms
function _add_quadraticcurve_variable_cost!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    proportional_term_per_unit::Float64,
    quadratic_term_per_unit::Float64,
) where {T <: VariableType}
    for t in get_time_steps(container)
        _add_quadraticcurve_variable_term_to_model!(
            container,
            T(),
            component,
            proportional_term_per_unit,
            quadratic_term_per_unit,
            t,
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
* cost_component::PSY.CostCurve{PSY.QuadraticCurve} : container for quadratic factors
"""
function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_function::PSY.CostCurve{PSY.QuadraticCurve},
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(T(), U())
    base_power = get_base_power(container)
    device_base_power = PSY.get_base_power(component)
    value_curve = PSY.get_value_curve(cost_function)
    power_units = PSY.get_power_units(cost_function)
    cost_component = PSY.get_function_data(value_curve)
    quadratic_term = PSY.get_quadratic_term(cost_component)
    proportional_term = PSY.get_proportional_term(cost_component)
    proportional_term_per_unit = get_proportional_cost_per_system_unit(
        proportional_term,
        power_units,
        base_power,
        device_base_power,
    )
    quadratic_term_per_unit = get_quadratic_cost_per_system_unit(
        quadratic_term,
        power_units,
        base_power,
        device_base_power,
    )
    _add_quadraticcurve_variable_cost!(
        container,
        T(),
        component,
        multiplier * proportional_term_per_unit,
        multiplier * quadratic_term_per_unit,
    )
    return
end

function _add_variable_cost_to_objective!(
    ::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_function::PSY.CostCurve{PSY.QuadraticCurve},
    ::U,
) where {
    T <: PowerAboveMinimumVariable,
    U <: Union{AbstractCompactUnitCommitment, ThermalCompactDispatch},
}
    throw(
        IS.ConflictingInputsError(
            "Quadratic Cost Curves are not allowed for Compact formulations",
        ),
    )
    return
end

function _add_fuel_quadratic_variable_cost!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    proportional_fuel_curve::Float64,
    quadratic_fuel_curve::Float64,
    fuel_cost::Float64,
) where {T <: VariableType}
    _add_quadraticcurve_variable_cost!(
        container,
        T(),
        component,
        proportional_fuel_curve * fuel_cost,
        quadratic_fuel_curve * fuel_cost,
    )
end

function _add_fuel_quadratic_variable_cost!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    proportional_fuel_curve::Float64,
    quadratic_fuel_curve::Float64,
    fuel_cost::IS.TimeSeriesKey,
) where {T <: VariableType}
    error("Not implemented yet")
    _add_quadraticcurve_variable_cost!(
        container,
        T(),
        component,
        proportional_fuel_curve,
        quadratic_fuel_curve,
    )
end

@doc raw"""
Adds to the cost function cost terms for sum of variables with common factor to be used for cost expression for optimization_container model.

# Equation

``` gen_cost = dt*(sum(variable.^2)*cost_data[1]*fuel_cost + sum(variable)*cost_data[2]*fuel_cost) ```

# LaTeX

`` cost = dt\times  (sum_{i\in I} c_f c_1 v_i^2 + sum_{i\in I} c_f c_2 v_i ) ``

for quadratic factor large enough. If the first term of the quadratic objective is 0.0, adds a
linear cost term `sum(variable)*cost_data[2]`

# Arguments

* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* var_key::VariableKey: The variable name
* component_name::String: The component_name of the variable container
* cost_component::PSY.FuelCurve{PSY.QuadraticCurve} : container for quadratic factors
"""
function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_function::PSY.FuelCurve{PSY.QuadraticCurve},
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(T(), U())
    base_power = get_base_power(container)
    device_base_power = PSY.get_base_power(component)
    value_curve = PSY.get_value_curve(cost_function)
    power_units = PSY.get_power_units(cost_function)
    cost_component = PSY.get_function_data(value_curve)
    quadratic_term = PSY.get_quadratic_term(cost_component)
    proportional_term = PSY.get_proportional_term(cost_component)
    proportional_term_per_unit = get_proportional_cost_per_system_unit(
        proportional_term,
        power_units,
        base_power,
        device_base_power,
    )
    quadratic_term_per_unit = get_quadratic_cost_per_system_unit(
        quadratic_term,
        power_units,
        base_power,
        device_base_power,
    )
    fuel_cost = PSY.get_fuel_cost(cost_function)
    # Multiplier is not necessary here. There is no negative cost for fuel curves.
    _add_fuel_quadratic_variable_cost!(
        container,
        T(),
        component,
        multiplier * proportional_term_per_unit,
        multiplier * quadratic_term_per_unit,
        fuel_cost,
    )
    return
end
