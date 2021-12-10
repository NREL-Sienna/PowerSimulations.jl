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
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ConstraintType,
    U <: VariableType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_variable(container, U(), V)
    _add_lower_bound_range_constraints_impl!(container, T, array, devices, model)
    _add_upper_bound_range_constraints_impl!(container, T, array, devices, model)
end

function add_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ConstraintType,
    U <: RangeConstraintLBExpressions,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_expression(container, U(), V)
    _add_lower_bound_range_constraints_impl!(container, T, array, devices, model)
end

function add_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ConstraintType,
    U <: RangeConstraintUBExpressions,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_expression(container, U(), V)
    _add_upper_bound_range_constraints_impl!(container, T, array, devices, model)
end

function add_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ComponentActivePowerVariableLimitsConstraint,
    U <: VariableType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_variable(container, U(), V)
    _add_lower_bound_range_constraints_impl!(container, T, array, devices, model)
    _add_upper_bound_range_constraints_impl!(container, T, array, devices, model)
    _add_parameterized_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
    )
end

function add_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ComponentActivePowerVariableLimitsConstraint,
    U <: RangeConstraintLBExpressions,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_expression(container, U(), V)
    _add_lower_bound_range_constraints_impl!(container, T, array, devices, model)
end

function add_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ComponentActivePowerVariableLimitsConstraint,
    U <: RangeConstraintUBExpressions,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_expression(container, U(), V)
    _add_upper_bound_range_constraints_impl!(container, T, array, devices, model)
    _add_parameterized_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
    )
end

function _add_lower_bound_range_constraints_impl!(
    container::OptimizationContainer,
    ::Type{T},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {T <: ConstraintType, V <: PSY.Component, W <: AbstractDeviceFormulation}
    time_steps = get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]

    con_lb =
        add_constraints_container!(container, T(), V, device_names, time_steps, meta = "lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        con_lb[ci_name, t] =
            JuMP.@constraint(container.JuMPmodel, array[ci_name, t] >= limits.min)
    end
end

function _add_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    ::Type{T},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {T <: ConstraintType, V <: PSY.Component, W <: AbstractDeviceFormulation}
    time_steps = get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]

    con_ub =
        add_constraints_container!(container, T(), V, device_names, time_steps, meta = "ub")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        con_ub[ci_name, t] =
            JuMP.@constraint(container.JuMPmodel, array[ci_name, t] <= limits.max)
    end
end

@doc raw"""
Constructs min/max range constraint from device variable and on/off decision variable.


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
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ConstraintType,
    U <: VariableType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_variable(container, U(), V)
    _add_semicontinuous_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
    )
    _add_semicontinuous_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
    )
end

function add_semicontinuous_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ConstraintType,
    U <: RangeConstraintLBExpressions,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_expression(container, U(), V)
    _add_semicontinuous_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
    )
end

function add_semicontinuous_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ConstraintType,
    U <: RangeConstraintUBExpressions,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_expression(container, U(), V)
    _add_semicontinuous_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        devices,
        model,
    )
end

function _add_semicontinuous_lower_bound_range_constraints_impl!(
    container::OptimizationContainer,
    ::Type{T},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
) where {T <: ConstraintType, V <: PSY.Component, W <: AbstractDeviceFormulation}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [OnVariable()]

    con_lb = add_constraints_container!(container, T(), V, names, time_steps, meta = "lb")

    @assert length(binary_variables) == 1 "Expected $(binary_variables) for $U $V $T $W to be length 1"
    varbin = get_variable(container, only(binary_variables), V)

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[ci_name, t] >= limits.min * varbin[ci_name, t]
        )
    end
end

function _add_semicontinuous_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    ::Type{T},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {T <: ConstraintType, V <: PSY.Component, W <: AbstractDeviceFormulation}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [OnVariable()]

    con_ub = add_constraints_container!(container, T(), V, names, time_steps, meta = "ub")

    @assert length(binary_variables) == 1 "Expected $(binary_variables) for $U $V $T $W to be length 1"
    varbin = get_variable(container, only(binary_variables), V)

    for device in devices, t in time_steps
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



``` varcts[name, t] <= limits.max * (1 - varbin[name, t]) ```

``` varcts[name, t] >= limits.min * (1 - varbin[name, t]) ```

where limits in constraint_infos.

# LaTeX

`` 0 \leq x^{cts} \leq limits^{max} (1 - x^{bin}), \text{ for } limits^{min} = 0 ``

`` limits^{min} (1 - x^{bin}) \leq x^{cts} \leq limits^{max} (1 - x^{bin}), \text{ otherwise } ``
"""
function add_reserve_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: InputActivePowerVariableLimitsConstraint,
    U <: VariableType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_variable(container, U(), V)
    _add_reserve_upper_bound_range_constraints_impl!(container, T, array, devices, model)
    _add_reserve_lower_bound_range_constraints_impl!(container, T, array, devices, model)
end

function add_reserve_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: InputActivePowerVariableLimitsConstraint,
    U <: ExpressionType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_expression(container, U(), W)
    _add_reserve_upper_bound_range_constraints_impl!(container, T, array, devices, model)
    _add_reserve_lower_bound_range_constraints_impl!(container, T, array, devices, model)
end

function _add_reserve_lower_bound_range_constraints_impl!(
    container::OptimizationContainer,
    ::Type{T},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
) where {
    T <: InputActivePowerVariableLimitsConstraint,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [ReservationVariable()]

    IS.@assert_op length(binary_variables) == 1
    varbin = get_variable(container, only(binary_variables), V)

    names = [PSY.get_name(x) for x in devices]
    # MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    # In the future this can be updated
    con_lb = add_constraints_container!(container, T(), V, names, time_steps, meta = "lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W)
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[ci_name, t] >= limits.min * (1 - varbin[ci_name, t])
        )
    end
end

function _add_reserve_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    ::Type{T},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {
    T <: InputActivePowerVariableLimitsConstraint,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [ReservationVariable()]

    IS.@assert_op length(binary_variables) == 1
    varbin = get_variable(container, only(binary_variables), V)

    names = [PSY.get_name(x) for x in devices]
    # MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    # In the future this can be updated
    con_ub = add_constraints_container!(container, T(), V, names, time_steps, meta = "ub")

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



``` varcts[name, t] <= limits.max * varbin[name, t] ```

``` varcts[name, t] >= limits.min * varbin[name, t] ```

where limits in constraint_infos.

# LaTeX

`` limits^{min} x^{bin} \leq x^{cts} \leq limits^{max} x^{bin},``
"""
function add_reserve_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{W},
    model::DeviceModel{W, X},
    ::Type{Y},
) where {
    T <:
    Union{ReactivePowerVariableLimitsConstraint, OutputActivePowerVariableLimitsConstraint},
    U <: VariableType,
    W <: PSY.Component,
    X <: AbstractDeviceFormulation,
    Y <: PM.AbstractPowerModel,
}
    array = get_variable(container, U(), W)
    _add_reserve_upper_bound_range_constraints_impl!(container, T, array, devices, model)
    _add_reserve_lower_bound_range_constraints_impl!(container, T, array, devices, model)
end

@doc raw"""
Constructs min/max range constraint from device variable and reservation decision variable.



``` varcts[name, t] <= limits.max * varbin[name, t] ```

``` varcts[name, t] >= limits.min * varbin[name, t] ```

where limits in constraint_infos.

# LaTeX

`` limits^{min} x^{bin} \leq x^{cts} \leq limits^{max} x^{bin},``
"""
function add_reserve_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{W},
    model::DeviceModel{W, X},
    ::Type{Y},
) where {
    T <:
    Union{ReactivePowerVariableLimitsConstraint, OutputActivePowerVariableLimitsConstraint},
    U <: ExpressionType,
    W <: PSY.Component,
    X <: AbstractDeviceFormulation,
    Y <: PM.AbstractPowerModel,
}
    array = get_expression(container, U(), W)
    _add_reserve_upper_bound_range_constraints_impl!(container, T, array, devices, model)
    _add_reserve_lower_bound_range_constraints_impl!(container, T, array, devices, model)
end

function _add_reserve_lower_bound_range_constraints_impl!(
    container::OptimizationContainer,
    ::Type{T},
    array,
    devices::IS.FlattenIteratorWrapper{W},
    ::DeviceModel{W, X},
) where {
    T <:
    Union{ReactivePowerVariableLimitsConstraint, OutputActivePowerVariableLimitsConstraint},
    W <: PSY.Component,
    X <: AbstractDeviceFormulation,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [ReservationVariable()]

    con_lb = add_constraints_container!(container, T(), W, names, time_steps, meta = "lb")

    @assert length(binary_variables) == 1 "Expected $(binary_variables) for $U $V $T $W to be length 1"
    varbin = get_variable(container, only(binary_variables), W)

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, X) # depends on constraint type and formulation type
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[ci_name, t] >= limits.min * varbin[ci_name, t]
        )
    end
end

function _add_reserve_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    ::Type{T},
    array,
    devices::IS.FlattenIteratorWrapper{W},
    ::DeviceModel{W, X},
) where {
    T <:
    Union{ReactivePowerVariableLimitsConstraint, OutputActivePowerVariableLimitsConstraint},
    W <: PSY.Component,
    X <: AbstractDeviceFormulation,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [ReservationVariable()]

    con_ub = add_constraints_container!(container, T(), W, names, time_steps, meta = "ub")

    @assert length(binary_variables) == 1 "Expected $(binary_variables) for $U $V $T $W to be length 1"
    varbin = get_variable(container, only(binary_variables), W)

    for device in devices, t in time_steps
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
    ::Type{T},
    ::Type{U},
    ::Type{P},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ConstraintType,
    U <: ExpressionType,
    P <: ParameterType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_expression(container, U(), V)
    _add_parameterized_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        P,
        devices,
        model,
    )
end

function add_parameterized_lower_bound_range_constraints(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    ::Type{P},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ConstraintType,
    U <: VariableType,
    P <: ParameterType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_variable(container, U(), V)
    _add_parameterized_lower_bound_range_constraints_impl!(
        container,
        T,
        array,
        P,
        devices,
        model,
    )
end

function _add_parameterized_lower_bound_range_constraints_impl!(
    container::OptimizationContainer,
    ::Type{T},
    array,
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {
    T <: ConstraintType,
    U <: ParameterType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    constraint =
        add_constraints_container!(container, T(), V, names, time_steps, meta = "lb")

    parameter = get_parameter_array(container, U(), V)
    multiplier = get_parameter_multiplier_array(container, U(), V)
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[name, t] >= multiplier[name, t] * parameter[name, t]
        )
    end
end

function add_parameterized_upper_bound_range_constraints(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    ::Type{P},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ConstraintType,
    U <: ExpressionType,
    P <: ParameterType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_expression(container, U(), V)
    _add_parameterized_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        P,
        devices,
        model,
    )
end

function add_parameterized_upper_bound_range_constraints(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    ::Type{P},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ConstraintType,
    U <: VariableType,
    P <: ParameterType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_variable(container, U(), V)
    _add_parameterized_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        P,
        devices,
        model,
    )
end

function _add_parameterized_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    ::Type{T},
    array,
    ::Type{P},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {
    T <: ConstraintType,
    P <: ParameterType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    constraint =
        add_constraints_container!(container, T(), V, names, time_steps, meta = "ub")

    parameter = get_parameter_array(container, P(), V)
    multiplier = get_parameter_multiplier_array(container, P(), V)
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[name, t] <= multiplier[name, t] * parameter[name, t]
        )
    end
end
