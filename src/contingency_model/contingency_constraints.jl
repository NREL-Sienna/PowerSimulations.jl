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
        add_parameterized_upper_bound_range_constraints(
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
        add_parameterized_upper_bound_range_constraints(
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
        add_parameterized_upper_bound_range_constraints(
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
