@doc raw"""
Constructs allowed rate-of-change constraints from variables, initial condtions, and rate data.

# Constraints
If t = 1:

``` variable[name, 1] - initial_conditions[ix].value <= rate_data[1][ix].up ```

``` initial_conditions[ix].value - variable[name, 1] <= rate_data[1][ix].down ```

If t > 1:

``` variable[name, t] - variable[name, t-1] <= rate_data[1][ix].up ```

``` variable[name, t-1] - variable[name, t] <= rate_data[1][ix].down ```

# LaTeX

`` r^{down} \leq x_1 - x_{init} \leq r^{up}, \text{ for } t = 1 ``

`` r^{down} \leq x_t - x_{t-1} \leq r^{up}, \forall t \geq 2 ``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* rate_data::Tuple{Vector{String}, Vector{UpDown}} : gives name (1) and max ramp up/down rates (2)
* initial_conditions::Vector{InitialCondition} : for time zero 'variable'
* cons_name::Symbol : name of the constraint
* var_name::Tuple{Symbol, Symbol, Symbol} : the name of the variable
"""
function device_linear_rateofchange!(
    container::OptimizationContainer,
    rate_data::Vector{DeviceRampConstraintInfo},
    cons_type::ConstraintType,
    var_type::VariableType,
    ::Type{T},
) where {T <: PSY.Component}
    parameters = built_for_recurrent_solves(container)
    time_steps = get_time_steps(container)

    variable = get_variable(container, var_type, T)

    set_name = [get_component_name(r) for r in rate_data]
    con_up = add_cons_container!(container, cons_type, T, set_name, time_steps, meta = "up")
    con_down =
        add_cons_container!(container, cons_type, T, set_name, time_steps, meta = "dn")

    for r in rate_data
        name = get_component_name(r)
        ic_power = get_value(get_ic_power(r))
        @debug "add rate_of_change_constraint" name ic_power
        @assert (parameters && isa(ic_power, PJ.ParameterRef)) || !parameters
        expression_ub = JuMP.AffExpr(0.0, variable[name, 1] => 1.0)
        for val in r.additional_terms_ub
            JuMP.add_to_expression!(expression_ub, get_variable(container, val)[name, 1])
        end
        con_up[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            expression_ub - ic_power <= r.ramp_limits.up
        )
        expression_lb = JuMP.AffExpr(0.0, variable[name, 1] => 1.0)
        for val in r.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(container, val)[name, 1],
                -1.0,
            )
        end
        con_down[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            ic_power - expression_lb <= r.ramp_limits.down
        )
    end

    for t in time_steps[2:end], r in rate_data
        name = get_component_name(r)
        expression_ub = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
        for val in r.additional_terms_ub
            JuMP.add_to_expression!(expression_ub, get_variable(container, val)[name, t])
        end
        con_up[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_ub - variable[name, t - 1] <= r.ramp_limits.up
        )
        expression_lb = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
        for val in r.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(container, val)[name, t],
                -1.0,
            )
        end
        con_down[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            variable[name, t - 1] - expression_lb <= r.ramp_limits.down
        )
    end

    return
end

@doc raw"""
Constructs allowed rate-of-change constraints from variables, initial condtions, start/stop status, and rate data

# Equations
If t = 1:

``` variable[name, 1] - initial_conditions[ix].value <= rate_data[1][ix].up + rate_data[2][ix].max*varstart[name, 1] ```

``` initial_conditions[ix].value - variable[name, 1] <= rate_data[1][ix].down + rate_data[2][ix].min*varstop[name, 1] ```

If t > 1:

``` variable[name, t] - variable[name, t-1] <= rate_data[1][ix].up + rate_data[2][ix].max*varstart[name, t] ```

``` variable[name, t-1] - variable[name, t] <= rate_data[1][ix].down + rate_data[2][ix].min*varstop[name, t] ```

# LaTeX

`` r^{down} + r^{min} x^{stop}_1 \leq x_1 - x_{init} \leq r^{up} + r^{max} x^{start}_1, \text{ for } t = 1 ``

`` r^{down} + r^{min} x^{stop}_t \leq x_t - x_{t-1} \leq r^{up} + r^{max} x^{start}_t, \forall t \geq 2 ``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* rate_data::Tuple{Vector{String}, Vector{UpDown}, Vector{MinMax}} : (1) gives name
                                                                     (2) gives min/max ramp rates
                                                                     (3) gives min/max for 'variable'
* initial_conditions::Vector{InitialCondition} : for time zero 'variable'
* cons_name::Symbol : name of the constraint
* var_keys::Tuple{VariableKey, VariableKey, VariableKey} : the names of the variables
- : var_keys[1] : 'variable'
- : var_keys[2] : 'varstart'
- : var_keys[3] : 'varstop'
"""
function device_mixedinteger_rateofchange!(
    container::OptimizationContainer,
    rate_data::Vector{DeviceRampConstraintInfo},
    cons_type::ConstraintType,
    var_types::Tuple{VariableType, VariableType, VariableType},
    ::Type{T},
) where {T <: PSY.Component}
    parameters = built_for_recurrent_solves(container)
    time_steps = get_time_steps(container)

    variable = get_variable(container, var_types[1], T)
    varstart = get_variable(container, var_types[2], T)
    varstop = get_variable(container, var_types[3], T)

    set_name = [get_component_name(r) for r in rate_data]
    con_up = add_cons_container!(container, cons_type, T, set_name, time_steps, meta = "up")
    con_down =
        add_cons_container!(container, cons_type, T, set_name, time_steps, meta = "dn")

    for r in rate_data
        name = get_component_name(r)
        ic_power = get_value(get_ic_power(r))
        @debug "add rate_of_change_constraint" name ic_power
        @assert (parameters && isa(ic_power, PJ.ParameterRef)) || !parameters
        expression_ub = JuMP.AffExpr(0.0, variable[name, 1] => 1.0)
        for val in r.additional_terms_ub
            JuMP.add_to_expression!(expression_ub, get_variable(container, val)[name, 1])
        end
        con_up[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            expression_ub - (ic_power) <=
            r.ramp_limits.up + r.limits.max * varstart[name, 1]
        )
        expression_lb = JuMP.AffExpr(0.0, variable[name, 1] => 1.0)
        for val in r.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(container, val)[name, 1],
                -1.0,
            )
        end
        con_down[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            (ic_power) - expression_lb <=
            r.ramp_limits.down + r.limits.min * varstop[name, 1]
        )
    end

    for t in time_steps[2:end], r in rate_data
        name = get_component_name(r)
        expression_ub = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
        for val in r.additional_terms_ub
            JuMP.add_to_expression!(expression_ub, get_variable(container, val)[name, t])
        end
        con_up[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_ub - variable[name, t - 1] <=
            r.ramp_limits.up + r.limits.max * varstart[name, 1]
        )
        expression_lb = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
        for val in r.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(container, val)[name, t],
                -1.0,
            )
        end
        con_down[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            variable[name, t - 1] - expression_lb <=
            r.ramp_limits.down + r.limits.min * varstop[name, t]
        )
    end

    return
end

@doc raw"""
Constructs allowed rate-of-change constraints from variables, initial condtions, start/stop status, and rate data

# Equations
If t = 1:

``` variable[name, 1] - initial_conditions[ix].value <= rate_data[1][ix].up ```

``` initial_conditions[ix].value - variable[name, 1] <= rate_data[1][ix].down ```

If t > 1:

``` variable[name, t] - variable[name, t-1] <= rate_data[1][ix].up  ```

``` variable[name, t-1] - variable[name, t] <= rate_data[1][ix].down ```

# LaTeX

`` r^{down}  \leq x_1 - x_{init} \leq r^{up}  \text{ for } t = 1 ``

`` r^{down} \leq x_t - x_{t-1} \leq r^{up}  \forall t \geq 2 ``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* rate_data::Tuple{Vector{String}, Vector{UpDown}, Vector{MinMax}} : (1) gives name
                                                                     (2) gives min/max ramp rates
                                                                     (3) gives min/max for 'variable'
* initial_conditions::Vector{InitialCondition} : for time zero 'variable'
* cons_name::Symbol : name of the constraint
* var_keys::Tuple{VariableKey, VariableKey, VariableKey} : the names of the variables
- : var_name : 'variable'
"""
function device_multistart_rateofchange!(
    container::OptimizationContainer,
    rate_data::Vector{DeviceRampConstraintInfo},
    cons_type::ConstraintType,
    var_type::VariableType,
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    variable = get_variable(container, var_type, T)

    set_name = [get_component_name(r) for r in rate_data]
    con_up = add_cons_container!(container, cons_type, T, set_name, time_steps, meta = "up")
    con_down =
        add_cons_container!(container, cons_type, T, set_name, time_steps, meta = "dn")

    for r in rate_data
        name = get_component_name(r)
        ic_power = get_value(get_ic_power(r))
        expression_ub = JuMP.AffExpr(0.0, variable[name, 1] => 1.0)
        for val in r.additional_terms_ub
            JuMP.add_to_expression!(expression_ub, get_variable(container, val)[name, 1])
        end
        con_up[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            expression_ub - (ic_power) <= r.ramp_limits.up
        )
        expression_lb = JuMP.AffExpr(0.0, variable[name, 1] => 1.0)
        for val in r.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(container, val)[name, 1],
                1.0,
            )
        end
        con_down[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            (ic_power) - expression_lb <= r.ramp_limits.down
        )
    end

    for t in time_steps[2:end], r in rate_data
        name = get_component_name(r)
        expression_ub = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
        for val in r.additional_terms_ub
            JuMP.add_to_expression!(expression_ub, get_variable(container, val)[name, t])
        end
        con_up[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_ub - variable[name, t - 1] <= r.ramp_limits.up
        )
        expression_lb = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
        for val in r.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(container, val)[name, t],
                1.0,
            )
        end
        con_down[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            variable[name, t - 1] - expression_lb <= r.ramp_limits.down
        )
    end

    return
end

function service_upward_rateofchange!(
    container::OptimizationContainer,
    rate_data::Vector{ServiceRampConstraintInfo},
    cons_type::ConstraintType,
    var_type::VariableType,
    service_name::AbstractString,
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)

    # TODO DT: is this change valid?
    variable = get_variable(container, var_type, T, service_name)

    set_name = [get_component_name(r) for r in rate_data]
    con_up = add_cons_container!(
        container,
        cons_type,
        T,
        set_name,
        time_steps,
        meta = service_name,
    )

    for r in rate_data, t in time_steps
        name = get_component_name(r)
        con_up[name, t] =
            JuMP.@constraint(container.JuMPmodel, variable[name, t] <= r.ramp_limits.up)
    end

    return
end

function service_downward_rateofchange!(
    container::OptimizationContainer,
    rate_data::Vector{ServiceRampConstraintInfo},
    cons_type::ConstraintType,
    var_type::VariableType,
    service_name::AbstractString,
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    # TODO DT: is this change valid?
    variable = get_variable(container, var_type, T, service_name)
    set_name = [get_component_name(r) for r in rate_data]
    con_down = add_cons_container!(
        container,
        cons_type,
        T,
        set_name,
        time_steps,
        meta = service_name,
    )

    for r in rate_data, t in time_steps
        name = get_component_name(r)
        con_down[name, t] =
            JuMP.@constraint(container.JuMPmodel, variable[name, t] <= r.ramp_limits.down)
    end

    return
end
