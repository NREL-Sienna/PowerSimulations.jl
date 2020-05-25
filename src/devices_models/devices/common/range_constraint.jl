@doc raw"""
    device_range(psi_container::PSIContainer,
                 range_data::Vector{DeviceRange},
                 cons_name::Symbol,
                 var_name::Symbol)

Constructs min/max range constraint from device variable.

# Constraints
If min and max within an epsilon width:

``` variable[name, t] == limits.max ```

Otherwise:

``` limits.min <= variable[name, t] <= limits.max ```

where limits in range_data.

# LaTeX

`` x = limits^{max}, \text{ for } |limits^{max} - limits^{min}| < \varepsilon ``

`` limits^{min} \leq x \leq limits^{max}, \text{ otherwise } ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* range_data::Vector{DeviceRange} : contains names and vector of min/max
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
"""
function device_range(
    psi_container::PSIContainer,
    range_data::Vector{DeviceRange},
    cons_name::Symbol,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")
    names = (d.name for d in range_data)
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, names, time_steps)

    for data in range_data, t in time_steps
        expression_ub = JuMP.AffExpr(0.0, variable[data.name, t] => 1.0)
        for val in data.additional_terms_ub
            JuMP.add_to_expression!(
                expression_ub,
                get_variable(psi_container, val)[data.name, t],
            )
        end
        expression_lb = JuMP.AffExpr(0.0, variable[data.name, t] => 1.0)
        for val in data.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(psi_container, val)[data.name, t],
                -1.0,
            )
        end
        con_ub[data.name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, expression_ub <= data.limits.max)
        con_lb[data.name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, expression_lb >= data.limits.min)
    end

    return
end

@doc raw"""
    device_semicontinuousrange(psi_container::PSIContainer,
                                    range_data::Vector{DeviceRange},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints
If device min = 0:

``` varcts[name, t] <= limits.max*varbin[name, t]) ```

``` varcts[name, t] >= 0.0 ```

Otherwise:

``` varcts[name, t] <= limits.max*varbin[name, t] ```

``` varcts[name, t] >= limits.min*varbin[name, t] ```

where limits in range_data.

# LaTeX

`` 0 \leq x^{cts} \leq limits^{max} x^{bin}, \text{ for } limits^{min} = 0 ``

`` limits^{min} x^{bin} \leq x^{cts} \leq limits^{max} x^{bin}, \text{ otherwise } ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* range_data::Vector{DeviceRange} : contains names and vector of min/max
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* binvar_name::Symbol : the name of the binary variable
"""
function device_semicontinuousrange(
    psi_container::PSIContainer,
    range_data::Vector{DeviceRange},
    cons_name::Symbol,
    var_name::Symbol,
    binvar_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    varcts = get_variable(psi_container, var_name)
    varbin = get_variable(psi_container, binvar_name)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")
    names = (d.name for d in range_data)
    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    #In the future this can be updated
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, names, time_steps)

    for data in range_data, t in time_steps
        if JuMP.has_lower_bound(varcts[data.name, t])
            JuMP.set_lower_bound(varcts[data.name, t], 0.0)
        end
        expression_ub = JuMP.AffExpr(0.0, varcts[data.name, t] => 1.0)
        for val in data.additional_terms_ub
            JuMP.add_to_expression!(
                expression_ub,
                get_variable(psi_container, val)[data.name, t],
            )
        end
        expression_lb = JuMP.AffExpr(0.0, varcts[data.name, t] => 1.0)
        for val in data.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(psi_container, val)[data.name, t],
                -1.0,
            )
        end
        con_ub[data.name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_ub <= data.limits.max * varbin[data.name, t]
        )
        con_lb[data.name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_lb >= data.limits.min * varbin[data.name, t]
        )
    end

    return
end
#This function looks suspicious and repetitive. Needs verification
@doc raw"""
    reserve_device_semicontinuousrange(psi_container::PSIContainer,
                                    range_data::Vector{DeviceRange},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints
If device min = 0:

``` varcts[name, t] <= limits.max * (1 - varbin[name, t]) ```

``` varcts[name, t] >= 0.0 ```

Otherwise:

``` varcts[name, t] <= limits.max * (1 - varbin[name, t]) ```

``` varcts[name, t] >= limits.min * (1 - varbin[name, t]) ```

where limits in range_data.

# LaTeX

`` 0 \leq x^{cts} \leq limits^{max} (1 - x^{bin} ), \text{ for } limits^{min} = 0 ``

`` limits^{min} (1 - x^{bin} ) \leq x^{cts} \leq limits^{max} (1 - x^{bin} ), \text{ otherwise } ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* range_data::Vector{DeviceRange} : contains names and vector of min/max
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* binvar_name::Symbol : the name of the binary variable
"""
function reserve_device_semicontinuousrange(
    psi_container::PSIContainer,
    range_data::Vector{DeviceRange},
    cons_name::Symbol,
    var_name::Symbol,
    binvar_name::Symbol,
)

    time_steps = model_time_steps(psi_container)
    varcts = get_variable(psi_container, var_name)
    varbin = get_variable(psi_container, binvar_name)

    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")
    names = (d.name for d in range_data)
    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    #In the future this can be updated
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, names, time_steps)

    for data in range_data, t in time_steps
        if JuMP.has_lower_bound(varcts[data.name, t])
            JuMP.set_lower_bound(varcts[data.name, t], 0.0)
        end
        expression_ub = JuMP.AffExpr(0.0, varcts[data.name, t] => 1.0)
        for val in data.additional_terms_ub
            JuMP.add_to_expression!(
                expression_ub,
                get_variable(psi_container, val)[data.name, t],
            )
        end
        expression_lb = JuMP.AffExpr(0.0, varcts[data.name, t] => 1.0)
        for val in data.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(psi_container, val)[data.name, t],
                -1.0,
            )
        end
        con_ub[data.name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_ub <= data.limits.max * (1 - varbin[data.name, t])
        )
        con_lb[data.name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_lb >= data.limits.min * (1 - varbin[data.name, t])
        )
    end
    return
end

@doc raw"""  #TODO: Finish the doc string
    device_pglibrange(psi_container::PSIContainer,
                        range_data::Vector{DeviceRange},
                        cons_name::Symbol,
                        var_name::Symbol,
                        binvar_name::Symbol)

Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints
If device min = 0:

``` varcts[name, t] <= limits.max*varbin[name, t]) ```

``` varcts[name, t] >= 0.0 ```

Otherwise:

``` varcts[name, t] <= limits.max*varbin[name, t] ```

``` varcts[name, t] >= limits.min*varbin[name, t] ```

where limits in range_data.

# LaTeX

`` 0 \leq x^{cts} \leq limits^{max} x^{bin}, \text{ for } limits^{min} = 0 ``

`` limits^{min} x^{bin} \leq x^{cts} \leq limits^{max} x^{bin}, \text{ otherwise } ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* range_data::Vector{DeviceRange} : contains names and vector of min/max
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* binvar_name::Symbol : the name of the binary variable
"""
function device_pglibrange(
    psi_container::PSI.PSIContainer,
    range_data::Vector{DeviceRangePGLIB},
    cons_name::Symbol,
    var_name::Symbol,
    binvar_name::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = PSI.model_time_steps(psi_container)
    varp = PSI.get_variable(psi_container, var_name)

    varstatus = PSI.get_variable(psi_container, binvar_name[1])
    varon = PSI.get_variable(psi_container, binvar_name[2])
    varoff = PSI.get_variable(psi_container, binvar_name[3])

    on_name = PSI.middle_rename(cons_name, PSI.PSI_NAME_DELIMITER, "on")
    off_name = PSI.middle_rename(cons_name, PSI.PSI_NAME_DELIMITER, "off")
    names = (d.name for d in range_data)
    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    #In the future this can be updated
    con_on = PSI.add_cons_container!(psi_container, on_name, names, time_steps)
    con_off = PSI.add_cons_container!(psi_container, off_name, names, time_steps)

    for data in range_data, t in time_steps
        #         if JuMP.has_lower_bound(varp[data.name, t])
        #             JuMP.set_lower_bound(varp[data.name, t], 0.0)
        #         end
        expression_products = JuMP.AffExpr(0.0, varp[data.name, t] => 1.0)
        for val in data.additional_terms_ub
            JuMP.add_to_expression!(
                expression_products,
                PSI.get_variable(psi_container, val)[data.name, t],
            )
        end
        con_on[data.name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_products <=
            (data.limits.max - data.limits.min) * varstatus[data.name, t] -
            max(data.limits.max - data.ramplimits.startup, 0) * varon[data.name, t]
        )
        if t == length(time_steps)
            #  Not sure if this is need 
            # con_off[data.name, t] = JuMP.@constraint(
            #     psi_container.JuMPmodel,
            #     expression_products <= (data.limits.max - data.limits.min) * varstatus[data.name, t] 
            # )
        else
            con_off[data.name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                expression_products <=
                (data.limits.max - data.limits.min) * varstatus[data.name, t] -
                max(data.limits.max - data.ramplimits.shutdown, 0) *
                varoff[data.name, t + 1]
            )
        end
    end

    return
end

@doc raw""" #TODO: Finish the doc string
    device_pglib_range_ic(psi_container::PSIContainer,
                        range_data::Vector{DeviceRange},
                        initial_conditions::Matrix{PSI.InitialCondition},
                        cons_name::Symbol,
                        var_name::Tuple{Symbol, Symbol})

Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints
If device min = 0:

``` varcts[name, t] <= limits.max*varbin[name, t]) ```

``` varcts[name, t] >= 0.0 ```

Otherwise:

``` varcts[name, t] <= limits.max*varbin[name, t] ```

``` varcts[name, t] >= limits.min*varbin[name, t] ```

where limits in range_data.

# LaTeX

`` 0 \leq x^{cts} \leq limits^{max} x^{bin}, \text{ for } limits^{min} = 0 ``

`` limits^{min} x^{bin} \leq x^{cts} \leq limits^{max} x^{bin}, \text{ otherwise } ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* range_data::Vector{DeviceRange} : contains names and vector of min/max
* initial_conditions::Matrix{PSI.InitialCondition} : 
* cons_name::Symbol : name of the constraint
* var_name::Tuple{Symbol, Symbol} : the name of the continuous variable
"""
function device_pglib_range_ic(
    psi_container::PSI.PSIContainer,
    range_data::Vector{DeviceRangePGLIB},
    initial_conditions::Matrix{PSI.InitialCondition},## 1 is initial power, 2 is initial status
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol},
)
    time_steps = PSI.model_time_steps(psi_container)
    variable = PSI.get_variable(psi_container, var_names[1])
    varstop = PSI.get_variable(psi_container, var_names[2])

    set_name = (PSI.device_name(ic) for ic in initial_conditions[:, 1])
    con = PSI.add_cons_container!(psi_container, cons_name, set_name)

    for (ix, ic) in enumerate(initial_conditions[:, 1])
        name = PSI.device_name(ic)
        data = range_data[ix]
        con[name] = JuMP.@constraint(
            psi_container.JuMPmodel,
            initial_conditions[ix, 2].value *
            (initial_conditions[ix, 1].value - data.limits.min) <=
            initial_conditions[ix, 2].value * (data.limits.max - data.limits.min) -
            max(data.limits.max - data.ramplimits.shutdown, 0) * varstop[data.name, 1]
        )
    end
    return
end
