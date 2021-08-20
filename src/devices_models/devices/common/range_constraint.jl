######## CONSTRAINTS ############

# Generic fallback functions
function get_startup_shutdown(
    device,
    ::Type{<:VariableType},
    ::Type{<:AbstractDeviceFormulation},
) #  -> Union{Nothing, NamedTuple{(:startup, :shutdown), Tuple{Float64, Float64}}}
    nothing
end

function get_min_max_limits(
    device,
    ::Type{<:VariableType},
    ::Type{<:AbstractDeviceFormulation},
) #  -> Union{Nothing, NamedTuple{(:min, :max), Tuple{Float64, Float64}}}
    (min = 0.0, max = 0.0)
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
function add_range_constraints!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    use_parameters = built_for_simulation(container)
    constraint = T()
    variable = U()
    component_type = V
    time_steps = get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]

    con_ub = add_cons_container!(
        container,
        constraint,
        component_type,
        device_names,
        time_steps,
        meta = "ub",
    )
    con_lb = add_cons_container!(
        container,
        constraint,
        component_type,
        device_names,
        time_steps,
        meta = "lb",
    )
    jump_variable = get_variable(container, variable, component_type)

    for (i, device) in enumerate(devices), t in time_steps
        ci_name = PSY.get_name(device)
        # TODO: deal with additional expressions terms for services
        expression_ub = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        expression_lb = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        con_ub[ci_name, t] =
            JuMP.@constraint(container.JuMPmodel, expression_ub <= limits.max)
        con_lb[ci_name, t] =
            JuMP.@constraint(container.JuMPmodel, expression_lb >= limits.min)
    end
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
function add_semicontinuous_range_constraints!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    use_parameters = built_for_simulation(container)
    constraint = T()
    variable = U()
    component_type = V
    time_steps = get_time_steps(container)
    jump_variable = get_variable(container, variable, component_type)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [OnVariable()]

    con_ub = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "ub",
    )
    con_lb = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "lb",
    )

    @assert length(binary_variables) == 1 "Expected $(binary_variables) for $U $V $T $W to be length 1"
    # TODO: dispatch the following function to use parameter jump instead based on feedforward
    varbin = get_variable(container, only(binary_variables), component_type)

    for (i, device) in enumerate(devices), t in time_steps
        ci_name = PSY.get_name(device)
        # TODO: deal with additional expressions terms for services
        # add_services_constraint!(expression_ub, model)
        # add_services_constraint!(expression_lb, model)
        if JuMP.has_lower_bound(jump_variable[ci_name, t])
            JuMP.set_lower_bound(jump_variable[ci_name, t], 0.0)
        end
        expression_ub = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        expression_lb = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        con_ub[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_ub <= limits.max * varbin[ci_name, t]
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_lb >= limits.min * varbin[ci_name, t]
        )
    end
end

@doc raw"""
Constructs min/max range constraint from device variable and reservation decision variable.

# Constraints

``` varcts[name, t] <= limits.max * (1 - varbin[name, t]) ```

``` varcts[name, t] >= limits.min * (1 - varbin[name, t]) ```

where limits in constraint_infos.

# LaTeX

`` 0 \leq x^{cts} \leq limits^{max} (1 - x^{bin}), \text{ for } limits^{min} = 0 ``

`` limits^{min} (1 - x^{bin}) \leq x^{cts} \leq limits^{max} (1 - x^{bin}), \text{ otherwise } ``
"""
function add_reserve_range_constraints!(
    container::OptimizationContainer,
    T::Type{InputActivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    use_parameters = built_for_simulation(container)
    constraint = T()
    variable = U()
    component_type = V
    time_steps = get_time_steps(container)
    jump_variable = get_variable(container, variable, component_type)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [ReservationVariable()]

    @assert length(binary_variables) == 1
    varbin = get_variable(container, only(binary_variables), component_type)

    names = [PSY.get_name(x) for x in devices]
    # MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    # In the future this can be updated
    con_ub = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "ub",
    )
    con_lb = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "lb",
    )

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W)
        if JuMP.has_lower_bound(jump_variable[ci_name, t])
            JuMP.set_lower_bound(jump_variable[ci_name, t], 0.0)
        end
        expression_ub = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        expression_lb = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        con_ub[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_ub <= limits.max * (1 - varbin[ci_name, t])
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_lb >= limits.min * (1 - varbin[ci_name, t])
        )
    end
end

@doc raw"""
Constructs min/max range constraint from device variable and reservation decision variable.

# Constraints

``` varcts[name, t] <= limits.max * varbin[name, t] ```

``` varcts[name, t] >= limits.min * varbin[name, t] ```

where limits in constraint_infos.

# LaTeX

`` limits^{min} x^{bin} \leq x^{cts} \leq limits^{max} x^{bin},``
"""
function add_reserve_range_constraints!(
    container::OptimizationContainer,
    T::Type{U},
    V::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{W},
    model::DeviceModel{W, X},
    Y::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    U <:
    Union{ReactivePowerVariableLimitsConstraint, OutputActivePowerVariableLimitsConstraint},
    W <: PSY.Component,
    X <: AbstractDeviceFormulation,
}
    use_parameters = built_for_simulation(container)
    constraint = T()
    variable = V()
    component_type = W
    time_steps = get_time_steps(container)
    jump_variable = get_variable(container, variable, component_type)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [ReservationVariable()]

    con_ub = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "ub",
    )
    con_lb = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "lb",
    )

    @assert length(binary_variables) == 1 "Expected $(binary_variables) for $U $V $T $W to be length 1"
    varbin = get_variable(container, only(binary_variables), component_type)

    for (i, device) in enumerate(devices), t in time_steps
        ci_name = PSY.get_name(device)
        # TODO: deal with additional expressions terms for services
        if JuMP.has_lower_bound(jump_variable[ci_name, t])
            JuMP.set_lower_bound(jump_variable[ci_name, t], 0.0)
        end
        expression_ub = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        expression_lb = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        limits = get_min_max_limits(device, T, X) # depends on constraint type and formulation type
        con_ub[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_ub <= limits.max * varbin[ci_name, t]
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_lb >= limits.min * varbin[ci_name, t]
        )
    end
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
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* range_data::Vector{DeviceRange} : contains names and vector of min/max
* initial_conditions::Matrix{InitialCondition} :
* cons_name::Symbol : name of the constraint
* var_type::VariableType : name of the shutdown variable
"""
function device_multistart_range_ic!(
    container::OptimizationContainer,
    range_data::Vector{DeviceMultiStartRangeConstraintsInfo},
    initial_conditions::Matrix{InitialCondition},## 1 is initial power, 2 is initial status
    cons_type::ConstraintType,
    var_type::VariableType,
    ::Type{T},
) where {T <: PSY.Component}
    varstop = get_variable(container, var_type, T)

    set_name = [get_device_name(ic) for ic in initial_conditions[:, 1]]
    con = add_cons_container!(container, cons_type, T, set_name)

    for (ix, ic) in enumerate(initial_conditions[:, 1])
        name = get_device_name(ic)
        data = range_data[ix]
        val = max(data.limits.max - data.lag_ramp_limits.shutdown, 0)
        con[name] = JuMP.@constraint(
            container.JuMPmodel,
            val * varstop[get_component_name(data), 1] <=
            initial_conditions[ix, 2].value * (data.limits.max - data.limits.min) -
            ic.value
        )
    end
    return
end

function reserve_power_ub!(
    container::OptimizationContainer,
    charging_range_data::Vector{DeviceRangeConstraintInfo},
    discharging_range_data::Vector{DeviceRangeConstraintInfo},
    cons_type::ConstraintType,
    var_types::Tuple{VariableType, VariableType},
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    var_in = get_variable(container, var_types[1], T)
    var_out = get_variable(container, var_types[2], T)
    names = [get_component_name(x) for x in charging_range_data]
    con_up = add_cons_container!(container, cons_type, T, names, time_steps, meta = "up")
    con_dn = add_cons_container!(container, cons_type, T, names, time_steps, meta = "dn")

    for (up_info, dn_info) in zip(charging_range_data, discharging_range_data),
        t in time_steps

        name = get_component_name(up_info)
        expression_up = JuMP.AffExpr(0.0)
        for val in up_info.additional_terms_ub
            JuMP.add_to_expression!(
                expression_up,
                get_variable(container, val)[name, t],
                1.0,
            )
        end
        expression_dn = JuMP.AffExpr(0.0)
        for val in dn_info.additional_terms_lb
            JuMP.add_to_expression!(
                expression_dn,
                get_variable(container, val)[name, t],
                1.0,
            )
        end
        con_up[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_up <= var_in[name, t] + (up_info.limits.max - var_out[name, t])
        )
        con_dn[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_dn <= var_out[name, t] + (dn_info.limits.max - var_in[name, t])
        )
    end
    return
end

function reserve_energy_ub!(
    container::OptimizationContainer,
    constraint_infos::Vector{ReserveRangeConstraintInfo},
    cons_type::ConstraintType,
    var_type::VariableType,
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    var_e = get_variable(container, var_type, T)
    names = [get_component_name(x) for x in constraint_infos]
    con_up = add_cons_container!(container, cons_type, T, names, time_steps, meta = "up")
    con_dn = add_cons_container!(container, cons_type, T, names, time_steps, meta = "dn")

    for const_info in constraint_infos, t in time_steps
        name = get_component_name(const_info)
        expression_up = JuMP.AffExpr(0.0)
        for val in const_info.additional_terms_up
            JuMP.add_to_expression!(
                expression_up,
                get_variable(container, val)[name, t],
                get_time_frame(const_info, val) / MINUTES_IN_HOUR,
            )
        end
        expression_dn = JuMP.AffExpr(0.0)
        for val in const_info.additional_terms_dn
            JuMP.add_to_expression!(
                expression_dn,
                get_variable(container, val)[name, t],
                get_time_frame(const_info, val) / MINUTES_IN_HOUR,
            )
        end
        con_up[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_up <=
            (var_e[name, t] - const_info.limits.min) * const_info.efficiency.out
        )
        con_dn[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_dn <=
            (const_info.limits.max - var_e[name, t]) / const_info.efficiency.in
        )
    end
    return
end
