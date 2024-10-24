function add_event_arguments!(container::OptimizationContainer,
    devices::T,
    device_model::DeviceModel{U, V},
    network_model::NetworkModel,
) where {
    T <: Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    V <: AbstractDeviceFormulation,
} where {U <: PSY.StaticInjection}
    for (key, event_model) in get_events(device_model)
        event_type = get_entry_type(key)
        event_model_type = get_event_model(event_model)
        devices_with_attrbts =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        @assert !isempty(devices_with_attrbts)
        parameter_type = get_parameter_type(event_type, event_model_type, U)
        add_parameters!(
            container,
            parameter_type,
            devices_with_attrbts,
            device_model,
            event_model,
        )
    end

    return
end

function _add_parameters!(
    container,
    ::AvailableStatusParameter,
    devices::Vector{U},
    device_model::DeviceModel{U, W},
    event_model::EventModel{V, X},
) where {
    U <: PSY.Component,
    V <: PSY.Contingency,
    W <: AbstractDeviceFormulation,
    X <: AbstractEventModel,
}
    @debug "adding" AvailableStatusParameter U V _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    time_steps = get_time_steps(container)
    parameter_container = add_param_container!(
        container,
        AvailableStatusParameter(),
        U,
        V,
        PSY.get_name.(devices),
        time_steps,
    )

    jump_model = get_jump_model(container)

    for d in devices
        name = PSY.get_name(d)
        for t in time_steps
            set_multiplier!(
                parameter_container,
                get_parameter_multiplier(AvailableStatusParameter(), d, W()),
                name,
                t,
            )
            set_parameter!(
                parameter_container,
                jump_model,
                1.0, # Initial Value as available
                name,
                t,
            )
        end
    end
    return
end
