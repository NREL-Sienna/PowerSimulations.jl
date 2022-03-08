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

function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    op_cost::PSY.OperationalCost,
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    variable_cost_data = variable_cost(op_cost, component, U())
    _add_variable_cost_to_objective!(container, T(), component, variable_cost_data, U())
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
    multiplier = objective_function_multiplier(component, U())
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
    multiplier = objective_function_multiplier(component, U())
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
                multiplier * base_power * dt,
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
    _add_to_objective_invariant_expression!(container, lin_cost, component)
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
    _add_to_objective_invariant_expression!(container, q_cost, component)
    return q_cost
end

function _add_to_objective_invariant_expression!(
    container::OptimizationContainer,
    cost_expr::T,
    ::U,
) where {T <: JuMP.AbstractJuMPScalar, U <: PSY.Component}
    T_cf = typeof(container.objective_function.invariant_terms)
    if T_cf <: JuMP.GenericAffExpr && T <: JuMP.GenericQuadExpr
        container.objective_function.invariant_terms += cost_expr
    else
        JuMP.add_to_expression!(container.objective_function.invariant_terms, cost_expr)
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
    pwl_cost_expressions = _add_pwl_term!(container, T, component, cost_data, U())
    for time_period in get_time_steps(container)
        add_to_expression!(
            container,
            ProductionCostExpression,
            pwl_cost_expressions[t],
            component,
            time_period,
        )
        _add_to_objective_invariant_expression!(
            container,
            pwl_cost_expressions[t],
            component,
        )
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
    ::T,
    d::PSY.Component,
    data::Vector{Tuple{Float64, Float64}},
    base_power::Float64,
) where {T <: VariableType}
    min = PSY.get_active_power_limits(d).min
    max = PSY.get_active_power_limits(d).max
    return _check_pwl_compact_data(min, max, data, base_power)
end

function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    data::Vector{NTuple{2, Float64}},
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    multiplier = objective_function_multiplier(d, V())
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    base_power = get_base_power(container)
    # Re-scale breakpoints by Basepower
    name = PSY.get_name(component)

    is_power_data_compact = _check_pwl_compact_data(U(), component, data, base_power)

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

    break_points = PSY.get_breakpoint_upperbounds(data) ./ base_power
    total_pwl_cost = JuMP.AffExpr(0.0)

    slopes = PSY.get_slopes(cost_data)
    # First element of the return is the average cost at P_min.
    # Shouldn't be passed for convexity check
    is_convex = _slope_convexity_check(slopes[2:end])
    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    for t in time_steps
        _add_pwl_variables!(container, T, name, time_period, data)
        _add_pwl_constraint!(container, component, U(), break_points, t)
        if !is_convex
            if has_container_key(container, OnStatusParameter, T)
                sos_val = SOSStatusVariable.PARAMETER
            else
                sos_val = sos_status(d, V())
            end
            _add_pwl_sos_constraint!(container, component, U(), break_points, sos_val, t)
        end
        pwl_cost = _get_cost_expression(container, component, t, data, multiplier * dt)
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
    period::Int,
) where {T <: PSY.Component, U <: VariableType}
    const_container = lazy_container_addition!(
        container,
        PieceWiseLinearCostConstraint(),
        U,
        axes(variables)...,
    )
    len_cost_data = length(break_points)
    jump_model = get_jump_model(container)
    variable = get_variable(container, U(), T)[name, time_period]
    pwl_vars = get_variable(container, PieceWiseLinearCostVariable(), T)
    name = PSY.get_name(component)
    const_container[name, time_period] = JuMP.@constraint(
        jump_model,
        variable ==
        sum(pwl_vars[name, ix, period] * break_points[ix] for ix in 1:len_cost_data)
    )
    return
end

function _add_pwl_sos_constraint!(
    container::OptimizationContainer,
    component::T,
    ::U,
    break_points::Vector{Float64},
    sos_status,
    period::Int,
) where {T <: PSY.Component, U <: VariableType}
    name = PSY.get_name(component)
    @warn(
        "The cost function provided for $(name) is not compatible with a linear PWL cost function.
  An SOS-2 formulation will be added to the model. This will result in additional binary variables."
    )
    if sos_status == SOSStatusVariable.NO_VARIABLE
        bin = 1.0
        @debug "Using Piecewise Linear cost function but no variable/parameter ref for ON status is passed. Default status will be set to online (1.0)" _group =
            LOG_GROUP_COST_FUNCTIONS

    elseif sos_status == SOSStatusVariable.PARAMETER
        bin = get_parameter(container, OnStatusParameter(), T).parameter_array[name]
        @debug "Using Piecewise Linear cost function with parameter OnStatusParameter, $T" _group =
            LOG_GROUP_COST_FUNCTIONS
    elseif sos_status == SOSStatusVariable.VARIABLE
        bin = get_variable(container, OnVariable(), T)[name, time_period]
        @debug "Using Piecewise Linear cost function with variable OnVariable $T" _group =
            LOG_GROUP_COST_FUNCTIONS
    else
        @assert false
    end
    pwl_vars = get_variable(container, PieceWiseLinearCostVariable(), T)
    bp_count = length(break_points)
    JuMP.@constraint(jump_model, sum(pwl_vars[name, i, period] for i in 1:bp_count) == bin)
    JuMP.@constraint(jump_model, pwl_vars in MOI.SOS2(collect(1:length(bp_count))))
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
            slopes[i] * upb[i] * multiplier * pwl_var_container[(name, i, time_period)],
        )
    end
    return gen_cost
end

function _convert_to_compact_variable_cost(var_cost::Vector{NTuple{2, Float64}})
    return [(c - no_load_cost, pp - p_min) for (c, pp) in var_cost]
end
