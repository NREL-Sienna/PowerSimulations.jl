struct RangeConstraintSpecInternal
    constraint_infos::Vector{<:AbstractRangeConstraintInfo}
    constraint_name::Symbol
    variable_name::Symbol
    bin_variable_names::Vector{Symbol}
    subcomponent_type::Union{Nothing, Type{<:PSY.Component}}
end

function RangeConstraintSpecInternal(
    constraint_infos::Vector{DeviceRangeConstraintInfo},
    constraint_name::Symbol,
    variable_name::Symbol,
)
    return RangeConstraintSpecInternal(
        constraint_infos,
        constraint_name,
        variable_name,
        Vector{Symbol}(),
        nothing,
    )
end

function RangeConstraintSpecInternal(;
    constraint_infos,
    constraint_name,
    variable_name,
    bin_variable_names = Vector{Symbol}(),
    subcomponent_type = nothing,
)
    return RangeConstraintSpecInternal(
        constraint_infos,
        constraint_name,
        variable_name,
        bin_variable_names,
        subcomponent_type,
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
function device_range!(
    optimization_container::OptimizationContainer,
    inputs::RangeConstraintSpecInternal,
)
    time_steps = model_time_steps(optimization_container)
    variable = get_variable(optimization_container, inputs.variable_name)
    ub_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "lb")
    names = [get_component_name(x) for x in inputs.constraint_infos]
    con_ub = add_cons_container!(optimization_container, ub_name, names, time_steps)
    con_lb = add_cons_container!(optimization_container, lb_name, names, time_steps)

    for constraint_info in inputs.constraint_infos, t in time_steps
        ci_name = get_component_name(constraint_info)
        idx = get_index(ci_name, t, inputs.subcomponent_type)
        expression_ub = JuMP.AffExpr(0.0, variable[idx] => 1.0)
        for val in constraint_info.additional_terms_ub
            JuMP.add_to_expression!(
                expression_ub,
                get_variable(optimization_container, val)[idx],
            )
        end
        expression_lb = JuMP.AffExpr(0.0, variable[idx] => 1.0)
        for val in constraint_info.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(optimization_container, val)[idx],
                -1.0,
            )
        end
        con_ub[ci_name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            expression_ub <= constraint_info.limits.max
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
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
function device_semicontinuousrange!(
    optimization_container::OptimizationContainer,
    inputs::RangeConstraintSpecInternal,
)
    time_steps = model_time_steps(optimization_container)
    varcts = get_variable(optimization_container, inputs.variable_name)
    @assert length(inputs.bin_variable_names) == 1
    varbin = get_variable(optimization_container, inputs.bin_variable_names[1])
    ub_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "lb")
    names = [get_component_name(x) for x in inputs.constraint_infos]
    # MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    # In the future this can be updated
    con_ub = add_cons_container!(optimization_container, ub_name, names, time_steps)
    con_lb = add_cons_container!(optimization_container, lb_name, names, time_steps)

    for constraint_info in inputs.constraint_infos, t in time_steps
        ci_name = get_component_name(constraint_info)
        idx = get_index(ci_name, t, inputs.subcomponent_type)
        if JuMP.has_lower_bound(varcts[idx])
            JuMP.set_lower_bound(varcts[idx], 0.0)
        end
        expression_ub = JuMP.AffExpr(0.0, varcts[idx] => 1.0)
        for val in constraint_info.additional_terms_ub
            JuMP.add_to_expression!(
                expression_ub,
                get_variable(optimization_container, val)[idx],
            )
        end
        expression_lb = JuMP.AffExpr(0.0, varcts[idx] => 1.0)
        for val in constraint_info.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(optimization_container, val)[idx],
                -1.0,
            )
        end
        con_ub[ci_name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            expression_ub <= constraint_info.limits.max * varbin[idx]
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            expression_lb >= constraint_info.limits.min * varbin[idx]
        )
    end

    return
end

# This function looks suspicious and repetitive. Needs verification
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
function reserve_device_semicontinuousrange!(
    optimization_container::OptimizationContainer,
    inputs::RangeConstraintSpecInternal,
)
    time_steps = model_time_steps(optimization_container)
    varcts = get_variable(optimization_container, inputs.variable_name)
    @assert length(inputs.bin_variable_names) == 1
    varbin = get_variable(optimization_container, inputs.bin_variable_names[1])

    ub_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "lb")
    names = [get_component_name(x) for x in inputs.constraint_infos]
    # MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    # In the future this can be updated
    con_ub = add_cons_container!(optimization_container, ub_name, names, time_steps)
    con_lb = add_cons_container!(optimization_container, lb_name, names, time_steps)

    for constraint_info in inputs.constraint_infos, t in time_steps
        ci_name = get_component_name(constraint_info)
        idx = get_index(ci_name, t, inputs.subcomponent_type)
        if JuMP.has_lower_bound(varcts[idx])
            JuMP.set_lower_bound(varcts[idx], 0.0)
        end
        expression_ub = JuMP.AffExpr(0.0, varcts[idx] => 1.0)
        for val in constraint_info.additional_terms_ub
            JuMP.add_to_expression!(
                expression_ub,
                get_variable(optimization_container, val)[idx],
            )
        end
        expression_lb = JuMP.AffExpr(0.0, varcts[idx] => 1.0)
        for val in constraint_info.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(optimization_container, val)[idx],
                -1.0,
            )
        end
        con_ub[ci_name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            expression_ub <= constraint_info.limits.max * (1 - varbin[idx])
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            expression_lb >= constraint_info.limits.min * (1 - varbin[idx])
        )
    end
    return
end

@doc raw"""
Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints

``` varcts[name, t] <= (limits.max-limits.min)*varbin[name, t])
        - max(limits.max - lag_ramp_limits.startup, 0) * var_on[name, t] ```

``` varcts[name, t] <= (limits.max-limits.min)*varbin[name, t])
        - max(limits.max - lag_ramp_limits.shutdown, 0) * var_off[name, t] ```

where limits and lag_ramp_limits is in range_data.

# LaTeX


`` x^{cts} \leq (limits^{max}-limits^{min}) x^{bin} - max(limits^{max} - lag^{startup}, 0) x^{on} ``

`` x^{cts} \leq (limits^{max}-limits^{min}) x^{bin} - max(limits^{max} - lag^{shutdown}, 0) x^{off}``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* range_data::Vector{DeviceRange} : contains names and vector of min/max
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* binvar_names::Symbol : the names of the binary variables
"""
function device_multistart_range!(
    optimization_container::OptimizationContainer,
    inputs::RangeConstraintSpecInternal,
)
    time_steps = model_time_steps(optimization_container)
    varp = get_variable(optimization_container, inputs.variable_name)
    @assert length(inputs.bin_variable_names) == 3
    varstatus = get_variable(optimization_container, inputs.bin_variable_names[1])
    varon = get_variable(optimization_container, inputs.bin_variable_names[2])
    varoff = get_variable(optimization_container, inputs.bin_variable_names[3])

    on_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "lb")
    off_name = middle_rename(inputs.constraint_name, PSI_NAME_DELIMITER, "ub")
    names = [get_component_name(x) for x in inputs.constraint_infos]
    con_on = add_cons_container!(optimization_container, on_name, names, time_steps)
    con_off = add_cons_container!(optimization_container, off_name, names, time_steps)

    for constraint_info in inputs.constraint_infos, t in time_steps
        name = get_component_name(constraint_info)
        idx = get_index(name, t, inputs.subcomponent_type)
        if JuMP.has_lower_bound(varp[idx])
            JuMP.set_lower_bound(varp[idx], 0.0)
        end
        expression_products = JuMP.AffExpr(0.0, varp[idx] => 1.0)
        for val in constraint_info.additional_terms_ub
            JuMP.add_to_expression!(
                expression_products,
                get_variable(optimization_container, val)[idx],
            )
        end
        con_on[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            expression_products <=
            (constraint_info.limits.max - constraint_info.limits.min) * varstatus[idx] -
            max(constraint_info.limits.max - constraint_info.lag_ramp_limits.startup, 0) * varon[idx]
        )
        if t == length(time_steps)
            continue
        else
            con_off[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                expression_products <=
                (constraint_info.limits.max - constraint_info.limits.min) * varstatus[idx] -
                max(
                    constraint_info.limits.max - constraint_info.lag_ramp_limits.shutdown,
                    0,
                ) * varoff[name, t + 1]
            )
        end
    end

    return
end

@doc raw"""
Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints

``` max(limits.max - lag_ramp_limits.shutdown, 0) var_off[name, 1] <= initial_power[ix].value
        - (limits.max - limits.min)initial_status[ix].value  ```

where limits in range_data.

# LaTeX

`` max(limits^{max} - lag^{shutdown}, 0) x^{off} \leq initial_condition^{power} - (limits^{max} - limits^{min}) initial_condition^{status}``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* range_data::Vector{DeviceRange} : contains names and vector of min/max
* initial_conditions::Matrix{InitialCondition} :
* cons_name::Symbol : name of the constraint
* var_name::Symbol : name of the shutdown variable
"""
function device_multistart_range_ic!(
    optimization_container::OptimizationContainer,
    range_data::Vector{DeviceMultiStartRangeConstraintsInfo},
    initial_conditions::Matrix{InitialCondition},## 1 is initial power, 2 is initial status
    cons_name::Symbol,
    var_name::Symbol,
)
    varstop = get_variable(optimization_container, var_name)

    set_name = [get_device_name(ic) for ic in initial_conditions[:, 1]]
    con = add_cons_container!(optimization_container, cons_name, set_name)

    for (ix, ic) in enumerate(initial_conditions[:, 1])
        name = get_device_name(ic)
        data = range_data[ix]
        val = max(data.limits.max - data.lag_ramp_limits.shutdown, 0)
        con[name] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            val * varstop[name, 1] <=
            initial_conditions[ix, 2].value * (data.limits.max - data.limits.min) -
            ic.value
        )
    end
    return
end

function reserve_power_ub!(
    optimization_container::OptimizationContainer,
    charging_range_data::Vector{DeviceRangeConstraintInfo},
    discharging_range_data::Vector{DeviceRangeConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol},
)
    time_steps = model_time_steps(optimization_container)
    var_in = get_variable(optimization_container, var_names[1])
    var_out = get_variable(optimization_container, var_names[2])
    rev_up_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "up")
    rev_dn_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "dn")
    names = [get_component_name(x) for x in charging_range_data]
    con_up = add_cons_container!(optimization_container, rev_up_name, names, time_steps)
    con_dn = add_cons_container!(optimization_container, rev_dn_name, names, time_steps)

    for (up_info, dn_info) in zip(charging_range_data, discharging_range_data),
        t in time_steps

        name = get_component_name(up_info)
        expression_up = JuMP.AffExpr(0.0)
        for val in up_info.additional_terms_ub
            JuMP.add_to_expression!(
                expression_up,
                get_variable(optimization_container, val)[name, t],
                1.0,
            )
        end
        expression_dn = JuMP.AffExpr(0.0)
        for val in dn_info.additional_terms_lb
            JuMP.add_to_expression!(
                expression_dn,
                get_variable(optimization_container, val)[name, t],
                1.0,
            )
        end
        con_up[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            expression_up <= var_in[name, t] + (up_info.limits.max - var_out[name, t])
        )
        con_dn[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            expression_dn <= var_out[name, t] + (dn_info.limits.max - var_in[name, t])
        )
    end
    return
end

function reserve_energy_ub!(
    optimization_container::OptimizationContainer,
    constraint_infos::Vector{ReserveRangeConstraintInfo},
    cons_name::Symbol,
    var_name::Symbol,
)
    time_steps = model_time_steps(optimization_container)
    var_e = get_variable(optimization_container, var_name)
    resolution = model_resolution(optimization_container)
    rev_up_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "up")
    rev_dn_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "dn")
    names = [get_component_name(x) for x in constraint_infos]
    con_up = add_cons_container!(optimization_container, rev_up_name, names, time_steps)
    con_dn = add_cons_container!(optimization_container, rev_dn_name, names, time_steps)

    for const_info in constraint_infos, t in time_steps
        name = get_component_name(const_info)
        expression_up = JuMP.AffExpr(0.0)
        for val in const_info.additional_terms_up
            JuMP.add_to_expression!(
                expression_up,
                get_variable(optimization_container, val)[name, t],
                get_time_frame(const_info, val) / MINUTES_IN_HOUR,
            )
        end
        expression_dn = JuMP.AffExpr(0.0)
        for val in const_info.additional_terms_dn
            JuMP.add_to_expression!(
                expression_dn,
                get_variable(optimization_container, val)[name, t],
                get_time_frame(const_info, val) / MINUTES_IN_HOUR,
            )
        end
        con_up[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            expression_up <=
            (var_e[name, t] - const_info.limits.min) * const_info.efficiency.out
        )
        con_dn[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            expression_dn <=
            (const_info.limits.max - var_e[name, t]) / const_info.efficiency.in
        )
    end
    return
end
