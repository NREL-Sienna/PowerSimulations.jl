function add_event_constraints!(
    container::OptimizationContainer,
    devices::T,
    device_model::DeviceModel{U, V},
    network_model::NetworkModel{W},
) where {
    T <: Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    V <: AbstractDeviceFormulation,
    W <: PM.AbstractActivePowerModel,
} where {U <: PSY.ThermalGen}
    for (key, event_model) in get_events(device_model)
        event_type = get_entry_type(key)
        devices_with_attributes =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        isempty(devices_with_attributes) &&
            error("no devices found with a supplemental attribute for event $event_type")
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            ActivePowerRangeExpressionUB,
            AvailableStatusParameter,
            devices_with_attributes,
            device_model,
            W,
        )
    end
    return
end

function add_event_constraints!(
    container::OptimizationContainer,
    devices::T,
    device_model::DeviceModel{U, V},
    network_model::NetworkModel{W},
) where {
    T <: Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    V <: AbstractDeviceFormulation,
    W <: PM.AbstractPowerModel,
} where {U <: PSY.ThermalGen}
    for (key, event_model) in get_events(device_model)
        event_type = get_entry_type(key)
        devices_with_attributes =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        isempty(devices_with_attributes) &&
            error("no devices found with a supplemental attribute for event $event_type")
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            ActivePowerRangeExpressionUB,
            AvailableStatusParameter,
            devices_with_attributes,
            device_model,
            W,
        )
        add_reactive_power_contingency_constraint(
            container,
            ReactivePowerOutageConstraint,
            ReactivePowerVariable,
            AvailableStatusParameter,
            devices_with_attributes,
            device_model,
            W,
        )
    end
    return
end

function add_event_constraints!(
    container::OptimizationContainer,
    devices::T,
    device_model::DeviceModel{U, V},
    network_model::NetworkModel{W},
) where {
    T <: Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    V <: AbstractDeviceFormulation,
    W <: PM.AbstractActivePowerModel,
} where {U <: PSY.RenewableGen}
    for (key, event_model) in get_events(device_model)
        event_type = get_entry_type(key)
        devices_with_attributes =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        isempty(devices_with_attributes) &&
            error("no devices found with a supplemental attribute for event $event_type")
        if has_service_model(device_model)
            lhs_type = ActivePowerRangeExpressionUB
        else
            lhs_type = ActivePowerVariable
        end
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            lhs_type,
            AvailableStatusParameter,
            devices_with_attributes,
            device_model,
            W,
        )
    end
    return
end

function add_event_constraints!(
    container::OptimizationContainer,
    devices::T,
    device_model::DeviceModel{U, V},
    network_model::NetworkModel{W},
) where {
    T <: Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    V <: AbstractDeviceFormulation,
    W <: PM.AbstractPowerModel,
} where {U <: PSY.RenewableGen}
    for (key, event_model) in get_events(device_model)
        event_type = get_entry_type(key)
        devices_with_attributes =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        isempty(devices_with_attributes) &&
            error("no devices found with a supplemental attribute for event $event_type")
        if has_service_model(device_model)
            lhs_type = ActivePowerRangeExpressionUB
        else
            lhs_type = ActivePowerVariable
        end
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            lhs_type,
            AvailableStatusParameter,
            devices_with_attributes,
            device_model,
            W,
        )
        add_reactive_power_contingency_constraint(
            container,
            ReactivePowerOutageConstraint,
            ReactivePowerVariable,
            AvailableStatusParameter,
            devices_with_attributes,
            device_model,
            W,
        )
    end
    return
end

function add_event_constraints!(
    container::OptimizationContainer,
    devices::T,
    device_model::DeviceModel{U, V},
    network_model::NetworkModel{W},
) where {
    T <: Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    V <: AbstractDeviceFormulation,
    W <: PM.AbstractActivePowerModel,
} where {U <: PSY.ElectricLoad}
    for (key, event_model) in get_events(device_model)
        event_type = get_entry_type(key)
        devices_with_attributes =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        isempty(devices_with_attributes) &&
            error("no devices found with a supplemental attribute for event $event_type")
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            ActivePowerVariable,
            AvailableStatusParameter,
            devices_with_attributes,
            device_model,
            W,
        )
    end
    return
end

function add_event_constraints!(
    container::OptimizationContainer,
    devices::T,
    device_model::DeviceModel{U, V},
    network_model::NetworkModel{W},
) where {
    T <: Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    V <: AbstractDeviceFormulation,
    W <: PM.AbstractPowerModel,
} where {U <: PSY.ElectricLoad}
    for (key, event_model) in get_events(device_model)
        event_type = get_entry_type(key)
        devices_with_attributes =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        isempty(devices_with_attributes) &&
            error("no devices found with a supplemental attribute for event $event_type")
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            ActivePowerVariable,
            AvailableStatusParameter,
            devices_with_attributes,
            device_model,
            W,
        )
        add_reactive_power_contingency_constraint(
            container,
            ReactivePowerOutageConstraint,
            ReactivePowerVariable,
            AvailableStatusParameter,
            devices_with_attributes,
            device_model,
            W,
        )
    end
    return
end

function add_reactive_power_contingency_constraint(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{R},
    ::Type{P},
    devices::Union{Vector{V}, IS.FlattenIteratorWrapper{V}},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ConstraintType,
    R <: VariableType,
    P <: ParameterType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array_reactive = get_variable(container, R(), V)
    _add_reactive_power_contingency_constraint_impl!(
        container,
        T,
        array_reactive,
        P(),
        devices,
        model,
    )
    return
end

function _add_reactive_power_contingency_constraint_impl!(
    container::OptimizationContainer,
    ::Type{T},
    array_reactive,
    param::P,
    devices::Union{Vector{V}, IS.FlattenIteratorWrapper{V}},
    model::DeviceModel{V, W},
) where {
    T <: ConstraintType,
    P <: ParameterType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
}
    time_steps = get_time_steps(container)
    names = PSY.get_name.(devices)
    constraint_container =
        add_constraints_container!(container, T(), V, names, time_steps; meta = "ub")

    param_array = get_parameter_array(container, param, V)
    param_multiplier = get_parameter_multiplier_array(container, P(), V)
    jump_model = get_jump_model(container)
    time_steps = axes(constraint_container)[2]
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        ub = _get_reactive_power_upper_bound(device)
        constraint_container[name, t] = JuMP.@constraint(
            jump_model,
            (array_reactive[name, t])^2 <= (ub * param_array[name, t])
        )
    end
    return
end

function _get_reactive_power_upper_bound(device::PSY.StaticInjection)
    return maximum([
        PSY.get_reactive_power_limits(device).max^2,
        PSY.get_reactive_power_limits(device).min^2,
    ])
end

function _get_reactive_power_upper_bound(device::PSY.ElectricLoad)
    return PSY.get_max_reactive_power(device)^2
end
