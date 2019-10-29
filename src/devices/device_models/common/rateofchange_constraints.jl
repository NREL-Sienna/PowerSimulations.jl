@doc raw"""
    device_linear_rateofchange(canonical::CanonicalModel,
                                    rate_data::Tuple{Vector{String}, Vector{UpDown}},
                                    initial_conditions::Vector{InitialCondition},
                                    cons_name::Symbol,
                                    var_name::Symbol)

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
* canonical::CanonicalModel : the canonical model built in PowerSimulations
* rate_data::Tuple{Vector{String}, Vector{UpDown}} : gives name (1) and max ramp up/down rates (2)
* initial_conditions::Vector{InitialCondition} : for time zero 'variable'
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the variable
"""
function device_linear_rateofchange(canonical::CanonicalModel,
                                    rate_data::Vector{UpDown},
                                    initial_conditions::Vector{InitialCondition},
                                    cons_name::Symbol,
                                    var_name::Symbol)

    time_steps = model_time_steps(canonical)
    up_name = _middle_rename(cons_name, "_", "up")
    down_name = _middle_rename(cons_name, "_", "dn")

    variable = var(canonical, var_name)

    set_name = (device_name(ic) for ic in initial_conditions)
    con_up = _add_cons_container!(canonical, up_name, set_name, time_steps)
    con_down = _add_cons_container!(canonical, down_name, set_name, time_steps)
    expr_cont_up = exp(canonical,Symbol(_remove_underscore(cons_name),"_up"))
    expr_cont_dn = exp(canonical,Symbol(_remove_underscore(cons_name),"_dn"))

    for (ix, ic) in enumerate(initial_conditions)
        name = device_name(ic)
        con_up[name, 1] = JuMP.@constraint(canonical.JuMPmodel, variable[name, 1] - get_condition(initial_conditions[ix])
                                                                + _get_expr(expr_cont_up,name, 1) <= rate_data[ix].up)
        con_down[name, 1] = JuMP.@constraint(canonical.JuMPmodel, get_condition(initial_conditions[ix]) - variable[name, 1]
                                                                - _get_expr(expr_cont_dn,name, 1) <= rate_data[ix].down)

    end

    for t in time_steps[2:end], (ix, ic) in enumerate(initial_conditions)
        name = device_name(ic)
        con_up[name, t] = JuMP.@constraint(canonical.JuMPmodel, variable[name, t] - variable[name, t-1] 
                                                                    + _get_expr(expr_cont_up,name, t)<= rate_data[ix].up)
        con_down[name, t] = JuMP.@constraint(canonical.JuMPmodel, variable[name, t-1] - variable[name, t] 
                                                                    - _get_expr(expr_cont_dn,name, t) <= rate_data[ix].down)
    end

    return

end

@doc raw"""
    device_mixedinteger_rateofchange(canonical::CanonicalModel,
                                          rate_data::Tuple{Vector{String}, Vector{UpDown}, Vector{MinMax}},
                                          initial_conditions::Vector{InitialCondition},
                                          cons_name::Symbol,
                                          var_names::Tuple{Symbol, Symbol, Symbol})

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
* canonical::CanonicalModel : the canonical model built in PowerSimulations
* rate_data::Tuple{Vector{String}, Vector{UpDown}, Vector{MinMax}} : (1) gives name
                                                                     (2) gives min/max ramp rates
                                                                     (3) gives min/max for 'variable'
* initial_conditions::Vector{InitialCondition} : for time zero 'variable'
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : 'variable'
- : var_names[2] : 'varstart'
- : var_names[3] : 'varstop'
"""
function device_mixedinteger_rateofchange(canonical::CanonicalModel,
                                          rate_data::Tuple{Vector{UpDown}, Vector{MinMax}},
                                          initial_conditions::Vector{InitialCondition},
                                          cons_name::Symbol,
                                          var_names::Tuple{Symbol, Symbol, Symbol})

    time_steps = model_time_steps(canonical)
    up_name = _middle_rename(cons_name, "_", "up")
    down_name = _middle_rename(cons_name, "_", "dn")

    variable = var(canonical, var_names[1])
    varstart = var(canonical, var_names[2])
    varstop = var(canonical, var_names[3])

    set_name = (device_name(ic) for ic in initial_conditions)
    con_up = _add_cons_container!(canonical, up_name, set_name, time_steps)
    con_down = _add_cons_container!(canonical, down_name, set_name, time_steps)
    expr_cont_up = exp(canonical,Symbol(_remove_underscore(cons_name),"_up"))
    expr_cont_dn = exp(canonical,Symbol(_remove_underscore(cons_name),"_dn"))

    for (ix, ic) in enumerate(initial_conditions)
        name = device_name(ic)
        con_up[name, 1] = JuMP.@constraint(canonical.JuMPmodel, variable[name, 1] + _get_expr(expr_cont_up,name, 1)
                                                            - initial_conditions[ix].value
                                                            <= rate_data[1][ix].up + rate_data[2][ix].max*varstart[name, 1])
        con_down[name, 1] = JuMP.@constraint(canonical.JuMPmodel, initial_conditions[ix].value - variable[name, 1]
                                                            - _get_expr(expr_cont_dn,name, 1)
                                                            <= rate_data[1][ix].down + rate_data[2][ix].min*varstop[name, 1])
    end

    for t in time_steps[2:end], (ix, ic) in enumerate(initial_conditions)
        name = device_name(ic)
        con_up[name, t] = JuMP.@constraint(canonical.JuMPmodel, variable[name, t] - variable[name, t-1]
                                                            + _get_expr(expr_cont_up,name, t)
                                                            <= rate_data[1][ix].up + rate_data[2][ix].max*varstart[name, t])
        con_down[name, t] = JuMP.@constraint(canonical.JuMPmodel, variable[name, t-1] - variable[name, t]
                                                            - _get_expr(expr_cont_dn,name, t)
                                                            <= rate_data[1][ix].down + rate_data[2][ix].min*varstop[name, t])
    end

    return

end


@doc raw"""
    device_rateofchange(canonical::CanonicalModel,
                        devices::Vector{T},
                        exp_name::Symbol,
                        var_name::Symbol) where {T<:PSY.Component}


Constructs expression for rate-of-change constraints from device variable.

# Expresion

``` expression_container[device_name, time_index] =+ variable ```

# Arguments
* canonical::CanonicalModel : the canonical model built in PowerSimulations
* devices::Vector{T} : contains devices
* exp_name::Symbol : name of the expresion that makes up the LHS of a constraint
* var_name::Symbol : the name of the continuous variable
"""
function device_rateofchange!(canonical::CanonicalModel,
                            devices::Vector{T},
                            exp_name::Symbol,
                            var_name::Symbol) where {T<:PSY.Component}

    time_steps = model_time_steps(canonical)
    var = PSI.var(canonical, var_name)
    exp_cont = exp(canonical, exp_name)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        if isassigned(exp_cont, name,t)
            JuMP.add_to_expression!(exp_cont[name, t], 1.0, var[name,t])
        else
            exp_cont[name,t] =  zero(eltype(exp_cont)) + 1.0*var[name,t];
        end
    end

    return

end
