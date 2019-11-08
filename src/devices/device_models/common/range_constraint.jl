@doc raw"""
    device_range(canonical::Canonical,
                        range_data::Vector{NamedMinMax},
                        cons_name::Symbol,
                        var_name::Symbol)

Constructs min/max range constraint from device variable.

# Constraints
If min and max within an epsilon width:

``` variable[r[1], t] == r[2].max ```

Otherwise:

``` r[2].min <= variable[r[1], t] <= r[2].max ```

where r in range_data.

# LaTeX

`` x = r^{max}, \text{ for } |r^{max} - r^{min}| < \varepsilon ``

`` r^{min} \leq x \leq r^{max}, \text{ otherwise } ``

# Arguments
* canonical::Canonical : the canonical model built in PowerSimulations
* range_data::Vector{NamedMinMax} : contains name of device (1) and its min/max (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
"""
function device_range(canonical::Canonical,
                    range_data::Vector{NamedMinMax},
                    cons_name::Symbol,
                    var_name::Symbol,
                    expr_name::Symbol)

    time_steps = model_time_steps(canonical)
    variable = var(canonical, var_name)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")

    set_name = (r[1] for r in range_data)
    con_ub = _add_cons_container!(canonical, ub_name, set_name, time_steps)
    con_lb = _add_cons_container!(canonical, lb_name, set_name, time_steps)
    
    expr_cont = exp(canonical,expr_name)
    ser_rdata = filter(x-> in(x[1], expr_cont.axes[1]), range_data) 
    non_serv_rdata = filter(x-> !in(x[1], expr_cont.axes[1]), range_data)

    for t in time_steps
        for r in ser_rdata
            if abs(r[2].min - r[2].max) <= eps()
            @warn("The min - max values in range constraint with eps() distance to each other. Range Constraint will be modified for Equality Constraint")
            con_ub[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, variable[r[1], t] 
                                                    + sum(expr_cont[r[1], t]) == r[2].max)

            else
            con_ub[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, variable[r[1], t] 
                                                    + sum(expr_cont[r[1], t]) <= r[2].max)

            con_lb[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, variable[r[1], t] 
                                                    + sum(expr_cont[r[1], t]) >= r[2].min)
            end
        end

        for r in non_serv_rdata
            if abs(r[2].min - r[2].max) <= eps()
            @warn("The min - max values in range constraint with eps() distance to each other. Range Constraint will be modified for Equality Constraint")
                    con_ub[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, variable[r[1], t] == r[2].max)
            else
                    con_ub[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, variable[r[1], t] <= r[2].max)

                    con_lb[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, variable[r[1], t] >= r[2].min)
            end
        end
    end

    return

end

@doc raw"""
    device_semicontinuousrange(canonical::Canonical,
                                    scrange_data::Vector{NamedMinMax},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints
If device min = 0:

``` varcts[r[1], t] <= r[2].max*varbin[r[1], t]) ```

``` varcts[r[1], t] >= 0.0 ```

Otherwise:

``` varcts[r[1], t] <= r[2].max*varbin[r[1], t] ```

``` varcts[r[1], t] >= r[2].min*varbin[r[1], t] ```

where r in range_data.

# LaTeX

`` 0 \leq x^{cts} \leq r^{max} x^{bin}, \text{ for } r^{min} = 0 ``

`` r^{min} x^{bin} \leq x^{cts} \leq r^{max} x^{bin}, \text{ otherwise } ``

# Arguments
* canonical::Canonical : the canonical model built in PowerSimulations
* scrange_data::Vector{NamedMinMax} : contains name of device (1) and its min/max (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* binvar_name::Symbol : the name of the binary variable
"""
function device_semicontinuousrange(canonical::Canonical,
                                    scrange_data::Vector{NamedMinMax},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol,
                                    expr_name::Symbol)

    time_steps = model_time_steps(canonical)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")

    varcts = get_variable(canonical, var_name)
    varbin = get_variable(canonical, binvar_name)

    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    #In the future this can be updated

    set_name = (r[1] for r in scrange_data)
    con_ub = _add_cons_container!(canonical, ub_name, set_name, time_steps)
    con_lb = _add_cons_container!(canonical, lb_name, set_name, time_steps)
    expr_cont = exp(canonical,expr_name)

    ser_rdata = filter(x-> in(x[1], expr_cont.axes[1]), scrange_data) 
    non_serv_rdata = filter(x-> !in(x[1], expr_cont.axes[1]), scrange_data)

    for t in time_steps 
        for r in ser_rdata
            # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
            if JuMP.has_lower_bound(varcts[r[1], t])
                JuMP.set_lower_bound(varcts[r[1], t], 0.0)
            end

            if r[2].min == 0.0
                con_ub[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] 
                                    + sum(expr_cont[r[1], t]) <= r[2].max*varbin[r[1], t])
                con_lb[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] 
                                                        + sum(expr_cont[r[1], t]) >= 0.0)
            else
                con_ub[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] 
                                    + sum(expr_cont[r[1], t]) <= r[2].max*varbin[r[1], t])
                con_lb[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] 
                                    + sum(expr_cont[r[1], t]) >= r[2].min*varbin[r[1], t])
            end
        end

        for r in non_serv_rdata
            # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
            if JuMP.has_lower_bound(varcts[r[1], t])
                JuMP.set_lower_bound(varcts[r[1], t], 0.0)
            end

            if r[2].min == 0.0
                con_ub[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] <= r[2].max*varbin[r[1], t])
                con_lb[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] >= 0.0)
            else
                con_ub[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] <= r[2].max*varbin[r[1], t])
                con_lb[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] >= r[2].min*varbin[r[1], t])
            end
        end
    end

    return

end

@doc raw"""
    reserve_device_semicontinuousrange(canonical::Canonical,
                                    scrange_data::Vector{NamedMinMax},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints
If device min = 0:

``` varcts[r[1], t] <= r[2].max*(1-varbin[r[1], t]) ```

``` varcts[r[1], t] >= 0.0 ```

Otherwise:

``` varcts[r[1], t] <= r[2].max*(1-varbin[r[1], t]) ```

``` varcts[r[1], t] >= r[2].min*(1-varbin[r[1], t]) ```

where r in range_data.

# LaTeX

`` 0 \leq x^{cts} \leq r^{max} (1 - x^{bin} ), \text{ for } r^{min} = 0 ``

`` r^{min} (1 - x^{bin} ) \leq x^{cts} \leq r^{max} (1 - x^{bin} ), \text{ otherwise } ``

# Arguments
* canonical::Canonical : the canonical model built in PowerSimulations
* scrange_data::Vector{NamedMinMax} : contains name of device (1) and its min/max (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* binvar_name::Symbol : the name of the binary variable
"""
function reserve_device_semicontinuousrange(canonical::Canonical,
                                            scrange_data::Vector{NamedMinMax},
                                            cons_name::Symbol,
                                            var_name::Symbol,
                                            binvar_name::Symbol)

    time_steps = model_time_steps(canonical)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")

    varcts = get_variable(canonical, var_name)
    varbin = get_variable(canonical, binvar_name)

    # MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    # In the future this can be updated

    set_name = (r[1] for r in scrange_data)
    con_ub = _add_cons_container!(canonical, ub_name, set_name, time_steps)
    con_lb = _add_cons_container!(canonical, lb_name, set_name, time_steps)

    for t in time_steps, r in scrange_data

            if r[2].min == 0.0

                con_ub[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] <= r[2].max*(1-varbin[r[1], t]))
                con_lb[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] >= 0.0)

            else

                con_ub[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] <= r[2].max*(1-varbin[r[1], t]))
                con_lb[r[1], t] = JuMP.@constraint(canonical.JuMPmodel, varcts[r[1], t] >= r[2].min*(1-varbin[r[1], t]))

            end

    end

    return

 end
