struct RangeConstraintInputsInternal
    constraint_infos::Vector{DeviceRangeConstraintInfo}
    constraint_name::Symbol
    variable_name::Symbol
    bin_variable_name::Union{Nothing, Symbol}
end

function RangeConstraintInputsInternal(
    constraint_infos::Vector{DeviceRangeConstraintInfo},
    constraint_name::Symbol,
    variable_name::Symbol,
)
    return RangeConstraintInputsInternal(
        constraint_infos,
        constraint_name,
        variable_name,
        nothing,
    )
end

@doc raw"""
Constructs min/max range constraint from device variable.

# Constraints
If min and max within an epsilon width:

``` variable[name, t] == limits.max ```

Otherwise:

``` limits.min <= variable[name, t] <= limits.max ```

where limits in constraint_infos.

# LaTeX

`` x = limits^{max}, \text{ for } |limits^{max} - limits^{min}| < \varepsilon ``

`` limits^{min} \leq x \leq limits^{max}, \text{ otherwise } ``
"""
function device_range(psi_container::PSIContainer, inputs::RangeConstraintInputsInternal)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, inputs.variable_name)
    ub_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "lb")
    names = (get_name(x) for x in inputs.constraint_infos)
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, names, time_steps)

    for constraint_info in inputs.constraint_infos, t in time_steps
        ci_name = get_name(constraint_info)
        expression_ub = JuMP.AffExpr(0.0, variable[ci_name, t] => 1.0)
        for val in constraint_info.additional_terms_ub
            JuMP.add_to_expression!(
                expression_ub,
                get_variable(psi_container, val)[ci_name, t],
            )
        end
        expression_lb = JuMP.AffExpr(0.0, variable[ci_name, t] => 1.0)
        for val in constraint_info.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(psi_container, val)[ci_name, t],
                -1.0,
            )
        end
        con_ub[ci_name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_ub <= constraint_info.limits.max
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_lb >= constraint_info.limits.min
        )
    end

    return
end

@doc raw"""
Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints
If device min = 0:

``` varcts[name, t] <= limits.max*varbin[name, t]) ```

``` varcts[name, t] >= 0.0 ```

Otherwise:

``` varcts[name, t] <= limits.max*varbin[name, t] ```

``` varcts[name, t] >= limits.min*varbin[name, t] ```

where limits in constraint_infos.

# LaTeX

`` 0 \leq x^{cts} \leq limits^{max} x^{bin}, \text{ for } limits^{min} = 0 ``

`` limits^{min} x^{bin} \leq x^{cts} \leq limits^{max} x^{bin}, \text{ otherwise } ``
"""
function device_semicontinuousrange(
    psi_container::PSIContainer,
    inputs::RangeConstraintInputsInternal,
)
    time_steps = model_time_steps(psi_container)
    varcts = get_variable(psi_container, inputs.variable_name)
    varbin = get_variable(psi_container, inputs.bin_variable_name)
    ub_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "lb")
    names = (get_name(x) for x in inputs.constraint_infos)
    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    #In the future this can be updated
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, names, time_steps)

    for constraint_info in inputs.constraint_infos, t in time_steps
        ci_name = get_name(constraint_info)
        if JuMP.has_lower_bound(varcts[ci_name, t])
            JuMP.set_lower_bound(varcts[ci_name, t], 0.0)
        end
        expression_ub = JuMP.AffExpr(0.0, varcts[ci_name, t] => 1.0)
        for val in constraint_info.additional_terms_ub
            JuMP.add_to_expression!(
                expression_ub,
                get_variable(psi_container, val)[ci_name, t],
            )
        end
        expression_lb = JuMP.AffExpr(0.0, varcts[ci_name, t] => 1.0)
        for val in constraint_info.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(psi_container, val)[ci_name, t],
                -1.0,
            )
        end
        con_ub[ci_name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_ub <= constraint_info.limits.max * varbin[ci_name, t]
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_lb >= constraint_info.limits.min * varbin[ci_name, t]
        )
    end

    return
end

#This function looks suspicious and repetitive. Needs verification
@doc raw"""
Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints
If device min = 0:

``` varcts[name, t] <= limits.max * (1 - varbin[name, t]) ```

``` varcts[name, t] >= 0.0 ```

Otherwise:

``` varcts[name, t] <= limits.max * (1 - varbin[name, t]) ```

``` varcts[name, t] >= limits.min * (1 - varbin[name, t]) ```

where limits in constraint_infos.

# LaTeX

`` 0 \leq x^{cts} \leq limits^{max} (1 - x^{bin} ), \text{ for } limits^{min} = 0 ``

`` limits^{min} (1 - x^{bin} ) \leq x^{cts} \leq limits^{max} (1 - x^{bin} ), \text{ otherwise } ``
"""
function reserve_device_semicontinuousrange(
    psi_container::PSIContainer,
    inputs::RangeConstraintInputsInternal,
)
    time_steps = model_time_steps(psi_container)
    varcts = get_variable(psi_container, inputs.variable_name)
    varbin = get_variable(psi_container, inputs.bin_variable_name)

    ub_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "lb")
    names = (x.name for x in inputs.constraint_infos)
    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    #In the future this can be updated
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, names, time_steps)

    for constraint_info in inputs.constraint_infos, t in time_steps
        ci_name = get_name(constraint_info)
        if JuMP.has_lower_bound(varcts[ci_name, t])
            JuMP.set_lower_bound(varcts[ci_name, t], 0.0)
        end
        expression_ub = JuMP.AffExpr(0.0, varcts[ci_name, t] => 1.0)
        for val in constraint_info.additional_terms_ub
            JuMP.add_to_expression!(
                expression_ub,
                get_variable(psi_container, val)[ci_name, t],
            )
        end
        expression_lb = JuMP.AffExpr(0.0, varcts[ci_name, t] => 1.0)
        for val in constraint_info.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(psi_container, val)[ci_name, t],
                -1.0,
            )
        end
        con_ub[ci_name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_ub <= constraint_info.limits.max * (1 - varbin[ci_name, t])
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_lb >= constraint_info.limits.min * (1 - varbin[ci_name, t])
        )
    end
    return
end

@doc raw"""  #TODO: Finish the doc string
    device_multistart_range(psi_container::PSIContainer,
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
function device_multistart_range(
    psi_container::PSI.PSIContainer,
    range_data::Vector{DeviceMultiStartRangeConstraintsData},
    cons_name::Symbol,
    var_name::Symbol,
    binvar_name::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = PSI.model_time_steps(psi_container)
    varp = PSI.get_variable(psi_container, var_name)

    varstatus = PSI.get_variable(psi_container, binvar_name[1])
    varon = PSI.get_variable(psi_container, binvar_name[2])
    varoff = PSI.get_variable(psi_container, binvar_name[3])

    on_name = PSI.middle_rename(cons_name, PSI.PSI_NAME_DELIMITER, "lb")
    off_name = PSI.middle_rename(cons_name, PSI.PSI_NAME_DELIMITER, "ub")
    names = (d.name for d in range_data)
    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    #In the future this can be updated
    con_on = PSI.add_cons_container!(psi_container, on_name, names, time_steps)
    con_off = PSI.add_cons_container!(psi_container, off_name, names, time_steps)

    for data in range_data, t in time_steps
        if JuMP.has_lower_bound(varp[data.name, t])
            JuMP.set_lower_bound(varp[data.name, t], 0.0)
        end
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
            max(data.limits.max - data.lag_ramp_limits.startup, 0) * varon[data.name, t]
        )
        if t == length(time_steps)
            #  TODO: Not sure if this is need 
            # con_off[data.name, t] = JuMP.@constraint(
            #     psi_container.JuMPmodel,
            #     expression_products <= (data.limits.max - data.limits.min) * varstatus[data.name, t] 
            # )
        else
            con_off[data.name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                expression_products <=
                (data.limits.max - data.limits.min) * varstatus[data.name, t] -
                max(data.limits.max - data.lag_ramp_limits.shutdown, 0) *
                varoff[data.name, t + 1]
            )
        end
    end

    return
end

@doc raw""" #TODO: Finish the doc string
    device_multistart_range_ic(psi_container::PSIContainer,
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
function device_multistart_range_ic(
    psi_container::PSI.PSIContainer,
    range_data::Vector{DeviceMultiStartRangeConstraintsData},
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
        val = max(data.limits.max - data.lag_ramp_limits.shutdown, 0)
        con[name] = JuMP.@constraint(
            psi_container.JuMPmodel,
            val * varstop[data.name, 1] <=  initial_conditions[ix, 2].value * (data.limits.max - data.limits.min) - ic.value  
        )
    end
    return
end
