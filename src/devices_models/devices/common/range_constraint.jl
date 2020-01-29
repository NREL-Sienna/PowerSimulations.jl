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
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")
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
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")
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
#This function looks suspicious and repetittive. Needs verification
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

    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")
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
