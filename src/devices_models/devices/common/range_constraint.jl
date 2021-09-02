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
    variable = U()
    component_type = V
    array = get_variable(container, variable, component_type)
    add_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        X,
        feedforward,
    )
    add_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        X,
        feedforward,
    )
end

function add_range_constraints!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{<:ExpressionType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    variable = U()
    component_type = V
    array = get_expression(container, variable, component_type)
    add_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        X,
        feedforward,
    )
    add_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        X,
        feedforward,
    )
end

function add_lower_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    use_parameters = built_for_recurrent_solves(container)
    constraint = T()
    component_type = V
    time_steps = get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]

    con_lb = add_cons_container!(
        container,
        constraint,
        component_type,
        device_names,
        time_steps,
        meta = "lb",
    )

    for (i, device) in enumerate(devices), t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        con_lb[ci_name, t] =
            JuMP.@constraint(container.JuMPmodel, array[ci_name, t] >= limits.min)
    end
end

function add_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    use_parameters = built_for_recurrent_solves(container)
    constraint = T()
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

    for (i, device) in enumerate(devices), t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        con_ub[ci_name, t] =
            JuMP.@constraint(container.JuMPmodel, array[ci_name, t] <= limits.max)
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
    variable = U()
    component_type = V
    array = get_variable(container, variable, component_type)
    add_semicontinuous_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        X,
        feedforward,
    )
    add_semicontinuous_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        X,
        feedforward,
    )
end

function add_semicontinuous_range_constraints!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{<:ExpressionType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    variable = U()
    component_type = V
    array = get_variable(container, variable, component_type)
    add_semicontinuous_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        X,
        feedforward,
    )
    add_semicontinuous_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        X,
        feedforward,
    )
end

function add_semicontinuous_lower_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    use_parameters = built_for_recurrent_solves(container)
    constraint = T()
    component_type = V
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [OnVariable()]

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
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[ci_name, t] >= limits.min * varbin[ci_name, t]
        )
    end
end

function add_semicontinuous_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    use_parameters = built_for_recurrent_solves(container)
    constraint = T()
    component_type = V
    time_steps = get_time_steps(container)
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

    @assert length(binary_variables) == 1 "Expected $(binary_variables) for $U $V $T $W to be length 1"
    varbin = get_variable(container, only(binary_variables), component_type)

    for (i, device) in enumerate(devices), t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        con_ub[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[ci_name, t] <= limits.max * varbin[ci_name, t]
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
    variable = U()
    component_type = W
    array = get_variable(container, variable, component_type)
    add_reserve_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        Y,
        feedforward,
    )
    add_reserve_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        Y,
        feedforward,
    )
end

function add_reserve_range_constraints!(
    container::OptimizationContainer,
    T::Type{InputActivePowerVariableLimitsConstraint},
    U::Type{<:ExpressionType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    expression = U()
    component_type = W
    array = get_expression(container, expression, component_type)
    add_reserve_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        Y,
        feedforward,
    )
    add_reserve_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        Y,
        feedforward,
    )
end

function add_reserve_lower_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{InputActivePowerVariableLimitsConstraint},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    use_parameters = built_for_recurrent_solves(container)
    constraint = T()
    component_type = V
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [ReservationVariable()]

    @assert length(binary_variables) == 1
    varbin = get_variable(container, only(binary_variables), component_type)

    names = [PSY.get_name(x) for x in devices]
    # MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    # In the future this can be updated
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
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[ci_name, t] >= limits.min * (1 - varbin[ci_name, t])
        )
    end
end

function add_reserve_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{InputActivePowerVariableLimitsConstraint},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    use_parameters = built_for_recurrent_solves(container)
    constraint = T()
    component_type = V
    time_steps = get_time_steps(container)
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

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W)
        con_ub[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[ci_name, t] <= limits.max * (1 - varbin[ci_name, t])
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
    variable = V()
    component_type = W
    array = get_expression(container, variable, component_type)
    add_reserve_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        Y,
        feedforward,
    )
    add_reserve_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        Y,
        feedforward,
    )
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
    V::Type{<:ExpressionType},
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
    expression = V()
    component_type = W
    array = get_variable(container, expression, component_type)
    add_reserve_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        Y,
        feedforward,
    )
    add_reserve_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
        Y,
        feedforward,
    )
end

function add_reserve_lower_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{U},
    array,
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
    use_parameters = built_for_recurrent_solves(container)
    constraint = T()
    component_type = W
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [ReservationVariable()]

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
        limits = get_min_max_limits(device, T, X) # depends on constraint type and formulation type
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[ci_name, t] >= limits.min * varbin[ci_name, t]
        )
    end
end

function add_reserve_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{U},
    array,
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
    use_parameters = built_for_recurrent_solves(container)
    constraint = T()
    component_type = W
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [ReservationVariable()]

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
        limits = get_min_max_limits(device, T, X) # depends on constraint type and formulation type
        con_ub[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[ci_name, t] <= limits.max * varbin[ci_name, t]
        )
    end
end

function add_parameterized_lower_bound_range_constraints(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{<:ExpressionType},
    P::Type{<:ParameterType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    variable = U()
    component_type = V
    array = get_expression(container, variable, component_type)
    add_parameterized_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        P,
        devices,
        model,
        X,
        feedforward,
    )
end

function add_parameterized_lower_bound_range_constraints(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{<:VariableType},
    P::Type{<:ParameterType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    variable = U()
    component_type = V
    array = get_variable(container, variable, component_type)
    add_parameterized_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        P,
        devices,
        model,
        X,
        feedforward,
    )
end

function add_parameterized_lower_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    array,
    P::Type{<:ParameterType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    time_steps = get_time_steps(container)
    constraint_type = T
    constraint = T()
    variable = U()
    component_type = V
    names = [PSY.get_name(d) for d in devices]

    constraint = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "lb",
    )

    parameter = get_parameter_array(container, P(), V)
    multiplier = get_parameter_multiplier_array(container, P(), V)
    for (i, device) in enumerate(devices), t in time_steps
        name = PSY.get_name(device)
        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[name, t] >= multiplier[name, t] * parameter[name, t]
        )
    end
end

function add_parameterized_upper_bound_range_constraints(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{<:ExpressionType},
    P::Type{<:ParameterType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    variable = U()
    constraint_type = T
    component_type = V
    array = get_expression(container, variable, component_type)
    add_parameterized_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        P,
        devices,
        model,
        X,
        feedforward,
    )
end

function add_parameterized_upper_bound_range_constraints(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{<:VariableType},
    P::Type{<:ParameterType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    variable = U()
    constraint_type = T
    component_type = V
    array = get_variable(container, variable, component_type)
    add_parameterized_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        P,
        devices,
        model,
        X,
        feedforward,
    )
end

function add_parameterized_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    array,
    P::Type{<:ParameterType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Component, W <: AbstractDeviceFormulation}
    time_steps = get_time_steps(container)
    constraint = T()
    component_type = V
    names = [PSY.get_name(d) for d in devices]

    constraint = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "ub",
    )

    parameter = get_parameter_array(container, P(), V)
    multiplier = get_parameter_multiplier_array(container, P(), V)
    for (i, device) in enumerate(devices), t in time_steps
        name = PSY.get_name(device)
        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[name, t] <= multiplier[name, t] * parameter[name, t]
        )
    end
end

# function add_parameterized_upper_bound_bigM_range_constraints(
#     container::OptimizationContainer,
#     T::Type{<:ConstraintType},
#     U::Type{<:VariableType},
#     P::Type{<:ParameterType},
#     devices::IS.FlattenIteratorWrapper{V},
#     model::DeviceModel{V, W},
#     X::Type{<:PM.AbstractPowerModel},
#     feedforward::Union{Nothing, AbstractAffectFeedForward},
# ) where {V <: PSY.Component, W <: AbstractDeviceFormulation}

#     # TODO: the following is incorrect implementation of bigM constraints

#     time_steps = get_time_steps(container)
#     constraint_type = T
#     constraint = T()
#     variable = U()
#     component_type = V
#     jump_variable = get_variable(container, variable, component_type)
#     names = [PSY.get_name(d) for d in devices]

#     constraint = add_cons_container!(
#         container,
#         constraint,
#         component_type,
#         names,
#         time_steps,
#         meta = "lb",
#     )

#     parameter = get_parameter_array(container, P(), V)
#     multiplier = get_parameter_multiplier_array(container, P(), V)
#     for (i, device) in enumerate(devices), t in time_steps
#         name = PSY.get_name(device)
#         expression_ub = JuMP.AffExpr(0.0, jump_variable[name, t] => 1.0)

#         # TODO: deal with additional terms

#         constraint[name, t] = JuMP.@constraint(
#             container.JuMPmodel,
#             expression_ub <= multiplier[name, t] * parameter[name, t]
#         )
#     end
# end
