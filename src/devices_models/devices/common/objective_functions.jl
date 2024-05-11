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
########### Cost Curve: LinearCurve ##############
##################################################

"""
Obtain proportional (marginal or slope) cost data in system base per unit
depending on the specified power units
"""
function get_proportional_cost_per_system_unit(
    cost_term::Float64,
    ::Val{0}, # SystemBase Unit
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term
end

function get_proportional_cost_per_system_unit(
    cost_term::Float64,
    ::Val{1}, # DeviceBase Unit
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term * (system_base_power / device_base_power)
end

function get_proportional_cost_per_system_unit(
    cost_term::Float64,
    ::Val{2}, # Natural Units
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term * system_base_power
end

"""
Adds to the cost function cost terms for sum of variables with common factor to be used for cost expression for optimization_container model.

# Arguments

  - container::OptimizationContainer : the optimization_container model built in PowerSimulations
  - var_key::VariableKey: The variable name
  - component_name::String: The component_name of the variable container
  - cost_component::PSY.CostCurve{PSY.LinearFunctionData} : container for cost to be associated with variable
"""
function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_function::PSY.CostCurve{PSY.LinearCurve},
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(T(), U())
    base_power = get_base_power(container)
    device_base_power = PSY.get_base_power(component)
    value_curve = PSY.get_value_curve(cost_function)
    power_units_value = PSY.get_power_units(cost_function).value
    cost_component = PSY.get_function_data(value_curve)
    proportional_term = PSY.get_proportional_term(cost_component)
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    proportional_term_per_unit = get_proportional_cost_per_system_unit(
        proportional_term,
        Val{power_units_value},
        base_power,
        device_base_power,
    )
    for time_period in get_time_steps(container)
        linear_cost = _add_proportional_term!(
            container,
            T(),
            component,
            proportional_term_per_unit * multiplier * dt,
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

##################################################
########## Cost Curve: Quadratic Curve ###########
##################################################

"""
Obtain quadratic (marginal or slope) cost data in system base per unit
depending on the specified power units
"""
function get_quadratic_cost_per_system_unit(
    cost_term::Float64,
    ::Val{0}, # SystemBase Unit
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term
end

function get_quadratic_cost_per_system_unit(
    cost_term::Float64,
    ::Val{1}, # DeviceBase Unit
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term * (system_base_power / device_base_power)^2
end

function get_quadratic_cost_per_system_unit(
    cost_term::Float64,
    ::Val{2}, # Natural Units
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term * system_base_power^2
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
    power_units_value = PSY.get_power_units(cost_function).value
    cost_component = PSY.get_function_data(value_curve)
    quadratic_term = PSY.get_quadratic_term(cost_component)
    proportional_term = PSY.get_proportional_term(cost_component)
    constant_term = PSY.get_constant_term(cost_component)
    (constant_term == 0) ||
        throw(ArgumentError("Not yet implemented for nonzero constant term"))
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    proportional_term_per_unit = get_proportional_cost_per_system_unit(
        proportional_term,
        Val{power_units_value},
        base_power,
        device_base_power,
    )
    quadratic_term_per_unit = get_quadratic_cost_per_system_unit(
        quadratic_term,
        Val{power_units_value},
        base_power,
        device_base_power,
    )
    for time_period in get_time_steps(container)
        if quadratic_term >= eps()
            cost_term = _add_quadratic_term!(
                container,
                T(),
                component,
                (quadratic_term_per_unit, proportional_term_per_unit),
                multiplier * dt,
                time_period,
            )
        else
            cost_term = _add_proportional_term!(
                container,
                T(),
                component,
                proportional_term_per_unit * multiplier * dt,
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

##################################################
################# SOS Methods ####################
##################################################

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

##################################################
######## CostCurve: PiecewisePointCurve ##########
##################################################

"""
Obtain the normalized PiecewiseLinear cost data in system base per unit
depending on the specified power units.

Note that the costs (y-axis) are always in $/h so
they do not require transformation
"""
function get_piecewise_pointcurve_per_system_unit(
    cost_component::PiecewiseLinearData,
    ::Val{0}, # SystemBase Units
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_component
end

function get_piecewise_pointcurve_per_system_unit(
    cost_component::PiecewiseLinearData,
    ::Val{1}, # DeviceBase Units
    system_base_power::Float64,
    device_base_power::Float64,
)
    points = cost_component.points
    points_normalized = Vector{NamedTuple{(:x, :y)}}(undef, length(points))
    for (ix, point) in enumerate(points)
        points_normalized[ix] =
            (x = point.x * (device_base_power / system_base_power), y = point.y) # case for natural units
    end
    return typeof(cost_component)(points_normalized)
end

function get_piecewise_pointcurve_per_system_unit(
    cost_component::PiecewiseLinearData,
    ::Val{2}, # Natural Units
    system_base_power::Float64,
    device_base_power::Float64,
)
    points = cost_component.points
    points_normalized = Vector{NamedTuple{(:x, :y)}}(undef, length(points))
    for (ix, point) in enumerate(points)
        points_normalized[ix] = (x = point.x / system_base_power, y = point.y) # case for natural units
    end
    return typeof(cost_component)(points_normalized)
end

"""
Creates piecewise linear cost function using a sum of variables and expression with sign and time step included.

# Arguments

  - container::OptimizationContainer : the optimization_container model built in PowerSimulations
  - var_key::VariableKey: The variable name
  - component_name::String: The component_name of the variable container
  - cost_function::PSY.CostCurve{PSY.PiecewisePointCurve}: container for piecewise linear cost
"""
function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_function::PSY.CostCurve{PSY.PiecewisePointCurve},
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    component_name = PSY.get_name(component)
    @debug "PWL Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    # If array is full of tuples with zeros return 0.0
    base_power = get_base_power(container)
    device_base_power = PSY.get_base_power(component)
    value_curve = PSY.get_value_curve(cost_function)
    cost_component = PSY.get_function_data(value_curve)
    power_units = PSY.get_power_units(cost_function).value
    if all(iszero.((point -> point.y).(PSY.get_points(cost_component))))  # TODO I think this should have been first. before?
        @debug "All cost terms for component $(component_name) are 0.0" _group =
            LOG_GROUP_COST_FUNCTIONS
        return
    end
    cost_component_normalized = get_piecewise_pointcurve_per_system_unit(
        cost_component,
        Val{power_units},
        base_power,
        device_base_power,
    )
    pwl_cost_expressions =
        _add_pwl_term!(container, component, cost_component_normalized, T(), U())
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
Add PWL cost terms for data coming from a PiecewisePointCurve
"""
function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    data::PSY.PiecewiseLinearData,
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    name = PSY.get_name(component)

    compact_status = validate_compact_pwl_data(component, data, base_power)
    if !uses_compact_power(component, V()) && compact_status == COMPACT_PWL_STATUS.VALID
        error(
            "The data provided is not compatible with formulation $V. Use a formulation compatible with Compact Cost Functions",
        )
        # data = _convert_to_full_variable_cost(data, component)
    elseif uses_compact_power(component, V()) && compact_status != COMPACT_PWL_STATUS.VALID
        @warn(
            "The cost data provided is not in compact form. Will attempt to convert. Errors may occur."
        )
        data = _convert_to_compact_variable_cost(data)
    else
        @debug uses_compact_power(component, V()) compact_status name T V
    end

    cost_is_convex = PSY.is_convex(data)
    break_points = PSY.get_x_coords(data)
    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    sos_val = _get_sos_value(container, V, component)
    for t in time_steps
        _add_pwl_variables!(container, T, name, t, data)
        _add_pwl_constraint!(container, component, U(), break_points, sos_val, t)
        if !cost_is_convex
            _add_pwl_sos_constraint!(container, component, U(), break_points, sos_val, t)
        end
        pwl_cost = _get_pwl_cost_expression(container, component, t, data, multiplier * dt)
        pwl_cost_expressions[t] = pwl_cost
    end
    return pwl_cost_expressions
end

"""
Add PWL cost terms for data coming from a PiecewisePointCurve for ThermalDispatchNoMin formulation
"""
function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    data::PSY.PiecewiseLinearData,
    ::U,
    ::V,
) where {T <: PSY.ThermalGen, U <: VariableType, V <: ThermalDispatchNoMin}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    component_name = PSY.get_name(component)
    @debug "PWL cost function detected for device $(component_name) using $V"
    slopes = PSY.get_slopes(data)
    if any(slopes .< 0) || !PSY.is_convex(data)
        throw(
            IS.InvalidValue(
                "The PWL cost data provided for generator $(component_name) is not compatible with $U.",
            ),
        )
    end

    if validate_compact_pwl_data(component, data, base_power) == COMPACT_PWL_STATUS.VALID
        error("The data provided is not compatible with formulation $V. \\
              Use a formulation compatible with Compact Cost Functions")
    end

    if slopes[1] != 0.0
        @debug "PWL has no 0.0 intercept for generator $(component_name)"
        # adds a first intercept a x = 0.0 and y below the intercept of the first tuple to make convex equivalent
        intercept_point = (x = 0.0, y = first(data).y - COST_EPSILON)
        data = PSY.PiecewiseLinearData(vcat(intercept_point, get_points(data)))
        @assert PSY.is_convex(slopes)
    end

    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    break_points = PSY.get_x_coords(data)
    sos_val = _get_sos_value(container, V, component)
    for t in time_steps
        _add_pwl_variables!(container, T, component_name, t, data)
        _add_pwl_constraint!(container, component, U(), break_points, sos_val, t)
        pwl_cost = _get_pwl_cost_expression(container, component, t, data, multiplier * dt)
        pwl_cost_expressions[t] = pwl_cost
    end
    return pwl_cost_expressions
end

##################################################
###### CostCurve: PiecewiseIncrementalCurve ######
######### and PiecewiseAverageCurve ##############
##################################################

"""
Creates piecewise linear cost function using a sum of variables and expression with sign and time step included.

# Arguments

  - container::OptimizationContainer : the optimization_container model built in PowerSimulations
  - var_key::VariableKey: The variable name
  - component_name::String: The component_name of the variable container
  - cost_function::PSY.Union{PSY.CostCurve{PSY.PiecewiseIncrementalCurve}, PSY.CostCurve{PSY.PiecewiseAverageCurve}}: container for piecewise linear cost
"""
function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_function::V,
    ::U,
) where {
    T <: VariableType,
    V <: Union{
        PSY.CostCurve{PSY.PiecewiseIncrementalCurve},
        PSY.CostCurve{PSY.PiecewiseAverageCurve},
    },
    U <: AbstractDeviceFormulation,
}
    # Create new PiecewisePointCurve
    value_curve = PSY.get_value_curve(cost_function)
    power_units = PSY.get_power_units(cost_function)
    pointbased_value_curve = PSY.InputOutputCurve(value_curve)
    pointbased_cost_function =
        PSY.CostCurve(; value_curve = pointbased_value_curve, power_units = power_units)
    # Call method for PiecewisePointCurve
    _add_variable_cost_to_objective!(
        container,
        T(),
        componen,
        pointbased_cost_function,
        U(),
    )
    return
end

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
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
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
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
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
            data = _convert_to_compact_variable_cost(data)
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
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
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

##################################################
################# PWL Variables ##################
##################################################

# This cases bounds the data by 1 - 0
function _add_pwl_variables!(
    container::OptimizationContainer,
    ::Type{T},
    component_name::String,
    time_period::Int,
    cost_data::PSY.PiecewiseLinearData,
) where {T <: PSY.Component}
    var_container = lazy_container_addition!(container, PieceWiseLinearCostVariable(), T)
    # length(PiecewiseStepData) gets number of segments, here we want number of points
    pwlvars = Array{JuMP.VariableRef}(undef, length(cost_data) + 1)
    for i in 1:(length(cost_data) + 1)
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

##################################################
################# PWL Constraints ################
##################################################

"""
Implement the constraints for PWL variables. That is:

```math
\\sum_{k\\in\\mathcal{K}} P_k^{max} \\delta_{k,t} = p_t \\\\
\\sum_{k\\in\\mathcal{K}} \\delta_{k,t} = on_t
```
"""
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
        param = get_default_on_parameter(component)
        bin = get_parameter(container, param, T).parameter_array[name, period]
        @debug "Using Piecewise Linear cost function with parameter OnStatusParameter, $T" _group =
            LOG_GROUP_COST_FUNCTIONS
    elseif sos_status == SOSStatusVariable.VARIABLE
        var = get_default_on_variable(component)
        bin = get_variable(container, var, T)[name, period]
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

"""
Implement the SOS for PWL variables. That is:

```math
\\{\\delta_{i,t}, ..., \\delta_{k,t}\\} \\in \\text{SOS}_2
```
"""
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

##################################################
################ PWL Expressions #################
##################################################

function _get_pwl_cost_expression(
    container::OptimizationContainer,
    component::T,
    time_period::Int,
    cost_data::PSY.PiecewiseLinearData,
    multiplier::Float64,
) where {T <: PSY.Component}
    name = PSY.get_name(component)
    pwl_var_container = get_variable(container, PieceWiseLinearCostVariable(), T)
    gen_cost = JuMP.AffExpr(0.0)
    cost_data = PSY.get_y_coords(cost_data)
    for i in 1:length(cost_data)
        JuMP.add_to_expression!(
            gen_cost,
            cost_data[i] * multiplier * pwl_var_container[(name, i, time_period)],
        )
    end
    return gen_cost
end

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
    for i in 1:length(cost_data)
        JuMP.add_to_expression!(
            gen_cost,
            cost_data[i] * multiplier * pwl_var_container[(name, i, time_period)],
        )
    end
    return gen_cost
end

##################################################
############### Auxiliary Methods ################
##################################################

# These conversions are not properly done for the new models
function _convert_to_compact_variable_cost(
    var_cost::PSY.PiecewiseLinearData,
    p_min::Float64,
    no_load_cost::Float64,
)
    points = PSY.get_points(var_cost)
    new_points = [(pp - p_min, c - no_load_cost) for (pp, c) in points]
    return PSY.PiecewiseLinearData(new_points)
end

# These conversions are not properly done for the new models
function _convert_to_compact_variable_cost(
    var_cost::PSY.PiecewiseStepData,
    p_min::Float64,
    no_load_cost::Float64,
)
    x = PSY.get_x_coords(var_cost)
    y = vcat(PSY.get_y_coords(var_cost), PSY.get_y_coords(var_cost)[end])
    points = [(x[i], y[i]) for i in length(x)]
    new_points = [(x = pp - p_min, y = c - no_load_cost) for (pp, c) in points]
    return PSY.PiecewiseLinearData(new_points)
end

# TODO: This method needs to be corrected to account for actual StepData. The TestData is point wise
function _convert_to_compact_variable_cost(var_cost::PSY.PiecewiseStepData)
    p_min, no_load_cost = (PSY.get_x_coords(var_cost)[1], PSY.get_y_coords(var_cost)[1])
    return _convert_to_compact_variable_cost(var_cost, p_min, no_load_cost)
end

function _convert_to_compact_variable_cost(var_cost::PSY.PiecewiseLinearData)
    p_min, no_load_cost = first(PSY.get_points(var_cost))
    return _convert_to_compact_variable_cost(var_cost, p_min, no_load_cost)
end
