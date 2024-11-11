function add_event_constraints!(
    container::OptimizationContainer,
    devices::T,
    device_model::DeviceModel{U, V},
    ::NetworkModel{W},
) where {
    T <: Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    V <: AbstractDeviceFormulation,
    W <: PM.AbstractActivePowerModel,
} where {U <: PSY.StaticInjection}
    for (key, event_model) in get_events(device_model)
        event_type = get_entry_type(key)
        devices_with_attrbts =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        @assert !isempty(devices_with_attrbts)
        parameter_type = get_parameter_type(event_type, event_model, U)
        lhs_type = ActivePowerRangeExpressionUB # get_lhs_type(container, device_model)
        add_parameterized_upper_bound_range_constraints(
            container,
            OutageConstraint,
            lhs_type,
            parameter_type,
            devices_with_attrbts,
            device_model,
            W,
        )
    end

    return
end
