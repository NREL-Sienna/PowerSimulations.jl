@doc raw"""
    device_range(ps_m::CanonicalModel,
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
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* range_data::Vector{NamedMinMax} : contains name of device (1) and its min/max (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
"""
function device_range(ps_m::CanonicalModel,
                        range_data::Vector{NamedMinMax},
                        cons_name::Symbol,
                        var_name::Symbol)

    time_steps = model_time_steps(ps_m)
    variable = var(ps_m, var_name)
    set_name = (r[1] for r in range_data)
    _add_cons_container!(ps_m, cons_name, set_name, time_steps)
    constraint = con(ps_m, cons_name)

    for r in range_data
          if abs(r[2].min - r[2].max) <= eps()
            @warn("The min - max values in range constraint with eps() distance to each other. Range Constraint will be modified for Equality Constraint")
                for t in time_steps
                    constraint[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, variable[r[1], t] == r[2].max)
                end
          else
                for t in time_steps
                    constraint[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, r[2].min <= variable[r[1], t] <= r[2].max)
                end
            end
    end

    return

end

@doc raw"""
    device_semicontinuousrange(ps_m::CanonicalModel,
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
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* scrange_data::Vector{NamedMinMax} : contains name of device (1) and its min/max (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* binvar_name::Symbol : the name of the binary variable
"""
function device_semicontinuousrange(ps_m::CanonicalModel,
                                    scrange_data::Vector{NamedMinMax},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

    time_steps = model_time_steps(ps_m)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")

    varcts = var(ps_m, var_name)
    varbin = var(ps_m, binvar_name)

    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    #In the future this can be updated

    set_name = (r[1] for r in scrange_data)
    _add_cons_container!(ps_m, ub_name, set_name, time_steps)
    _add_cons_container!(ps_m, lb_name, set_name, time_steps)
    con_ub = con(ps_m, ub_name)
    con_lb = con(ps_m, lb_name)

    for t in time_steps, r in scrange_data

            if r[2].min == 0.0

                con_ub[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, varcts[r[1], t] <= r[2].max*varbin[r[1], t])
                con_lb[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, varcts[r[1], t] >= 0.0)

            else

                con_ub[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, varcts[r[1], t] <= r[2].max*varbin[r[1], t])
                con_lb[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, varcts[r[1], t] >= r[2].min*varbin[r[1], t])

            end

    end

    return

end

@doc raw"""
    device_semicontinuousrange_param(ps_m::CanonicalModel,
                                    scrange_data::Vector{NamedMinMax},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    param_name::Symbol)

Constructs min/max range constraint from device variable with parameter setting.

# Constraints
If device min = 0:

``` variable[r[1], t] <= r[2].max*param[r[1], t] ```

``` varcts[r[1], t] >= 0.0 ```

Otherwise:

``` variable[r[1], t] <= r[2].max*param[r[1], t] ```

``` variable[r[1], t] >= r[2].min*param[r[1], t] ```

where r in range_data.

# LaTeX

`` 0.0 \leq x^{var} \leq r^{max} x^{param}, \text{ for } r^{min} = 0 ``

`` r^{min} x^{param} \leq x^{var} \leq r^{min} x^{param}, \text{ otherwise } ``

# Arguments
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* scrange_data::Vector{NamedMinMax} : contains name of device (1) and its min/max (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* param_name::Symbol : the name of the parameter
"""
function device_semicontinuousrange_param(ps_m::CanonicalModel,
                                          scrange_data::Vector{NamedMinMax},
                                          cons_name::Symbol,
                                          var_name::Symbol,
                                          param_name::Symbol)

    time_steps = model_time_steps(ps_m)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")

    variable = var(ps_m, var_name)


    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it. In the future this can be updated
    set_name = (r[1] for r in scrange_data)
    _add_param_container!(ps_m, param_name, set_name, time_steps)
    param = par(ps_m, param_name)

    _add_cons_container!(ps_m, ub_name, set_name, time_steps)
    _add_cons_container!(ps_m, lb_name, set_name, time_steps)
    con_ub = con(ps_m, ub_name)
    con_lb = con(ps_m, lb_name)
    #ps_m.parameters[param_name] = JuMPParamArray(undef, set_name, time_steps)
    #ps_m.constraints[ub_name] = JuMPConstraintArray(undef, set_name, time_steps)
    #ps_m.constraints[lb_name] = JuMPConstraintArray(undef, set_name, time_steps)

    for t in time_steps, r in scrange_data
        param[r[1], t] = PJ.add_parameter(ps_m.JuMPmodel, 1.0)
        if r[2].min == 0.0

            con_ub[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, variable[r[1], t] <= r[2].max*param[r[1], t])
            con_lb[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, variable[r[1], t] >= 0.0)

        else

            con_ub[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, variable[r[1], t] <= r[2].max*param[r[1], t])
            con_lb[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, variable[r[1], t] >= r[2].min*param[r[1], t])

        end

    end

    return

end

@doc raw"""
    reserve_device_semicontinuousrange(ps_m::CanonicalModel,
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
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* scrange_data::Vector{NamedMinMax} : contains name of device (1) and its min/max (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* binvar_name::Symbol : the name of the binary variable
"""
function reserve_device_semicontinuousrange(ps_m::CanonicalModel,
                                            scrange_data::Vector{NamedMinMax},
                                            cons_name::Symbol,
                                            var_name::Symbol,
                                            binvar_name::Symbol)

    time_steps = model_time_steps(ps_m)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")

    varcts = var(ps_m, var_name)
    varbin = var(ps_m, binvar_name)

    # MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    # In the future this can be updated

    set_name = (r[1] for r in scrange_data)
    _add_cons_container!(ps_m, ub_name, set_name, time_steps)
    _add_cons_container!(ps_m, lb_name, set_name, time_steps)
    con_ub = con(ps_m, ub_name)
    con_lb = con(ps_m, lb_name)

    for t in time_steps, r in scrange_data

            if r[2].min == 0.0

                con_ub[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, varcts[r[1], t] <= r[2].max*(1-varbin[r[1], t]))
                con_lb[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, varcts[r[1], t] >= 0.0)

            else

                con_ub[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, varcts[r[1], t] <= r[2].max*(1-varbin[r[1], t]))
                con_lb[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, varcts[r[1], t] >= r[2].min*(1-varbin[r[1], t]))

            end

    end

    return

 end
