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
        devices_with_attrbts =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        @assert !isempty(devices_with_attrbts)
        parameter_type = get_parameter_type(event_type, event_model, U)
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            ActivePowerRangeExpressionUB,
            parameter_type,
            devices_with_attrbts,
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
        devices_with_attrbts =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        @assert !isempty(devices_with_attrbts)
        parameter_type = get_parameter_type(event_type, event_model, U)
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            ActivePowerRangeExpressionUB,
            parameter_type,
            devices_with_attrbts,
            device_model,
            W,
        )
        add_parameterized_upper_bound_range_constraints(
            container,
            ReactivePowerOutageConstraint,
            ReactivePowerVariable,
            parameter_type,
            devices_with_attrbts,
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
        devices_with_attrbts =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        @assert !isempty(devices_with_attrbts)
        parameter_type = get_parameter_type(event_type, event_model, U)
        if has_service_model(device_model)
            lhs_type = ActivePowerRangeExpressionUB
        else
            lhs_type = ActivePowerVariable
        end
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            lhs_type,
            parameter_type,
            devices_with_attrbts,
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
        devices_with_attrbts =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        @assert !isempty(devices_with_attrbts)
        parameter_type = get_parameter_type(event_type, event_model, U)
        if has_service_model(device_model)
            lhs_type = ActivePowerRangeExpressionUB
        else
            lhs_type = ActivePowerVariable
        end
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            lhs_type,
            parameter_type,
            devices_with_attrbts,
            device_model,
            W,
        )
        add_parameterized_upper_bound_range_constraints(
            container,
            ReactivePowerOutageConstraint,
            ReactivePowerVariable,
            parameter_type,
            devices_with_attrbts,
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
        devices_with_attrbts =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        @assert !isempty(devices_with_attrbts)
        parameter_type = get_parameter_type(event_type, event_model, U)
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            ActivePowerVariable,
            parameter_type,
            devices_with_attrbts,
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
        devices_with_attrbts =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        @assert !isempty(devices_with_attrbts)
        parameter_type = get_parameter_type(event_type, event_model, U)
        add_parameterized_upper_bound_range_constraints(
            container,
            ActivePowerOutageConstraint,
            ActivePowerVariable,
            parameter_type,
            devices_with_attrbts,
            device_model,
            W,
        )
        add_parameterized_upper_bound_range_constraints(
            container,
            ReactivePowerOutageConstraint,
            ReactivePowerVariable,
            parameter_type,
            devices_with_attrbts,
            device_model,
            W,
        )
    end
    return
end
