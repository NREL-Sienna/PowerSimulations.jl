function add_event_arguments!(
    container::OptimizationContainer,
    devices::T,
    device_model::DeviceModel{U, V},
    network_model::NetworkModel,
) where {
    T <: Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    V <: AbstractDeviceFormulation,
} where {U <: PSY.StaticInjection}
    for (key, event_model) in get_events(device_model)
        event_type = get_entry_type(key)
        devices_with_attrbts =
            [d for d in devices if PSY.has_supplemental_attributes(d, event_type)]
        @assert !isempty(devices_with_attrbts)
        parameter_type = get_parameter_type(event_type, event_model, U)
        for p_type in [AvailableStatusChangeCountdownParameter, parameter_type]
            add_parameters!(
                container,
                p_type,
                devices_with_attrbts,
                device_model,
                event_model,
            )
        end
    end

    return
end

function add_event_arguments!(
    ::OptimizationContainer,
    ::T,
    ::DeviceModel{U, FixedOutput},
    ::NetworkModel,
) where {
    T <: Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
} where {U <: PSY.StaticInjection}
    throw(IS.ConflictingInputsError(
        "Outage Modeling is not compatible with FixedOutut Formulations"
    ))
    return
end


function _add_parameters!(
    container,
    ::T,
    devices::Vector{U},
    device_model::DeviceModel{U, W},
    event_model::EventModel{V, X},
) where {
    T <: EventParameter,
    U <: PSY.Component,
    V <: PSY.Contingency,
    W <: AbstractDeviceFormulation,
    X <: AbstractEventCondition,
}
    @debug "adding" T U V _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    time_steps = get_time_steps(container)
    parameter_container = add_param_container!(
        container,
        T(),
        U,
        V,
        PSY.get_name.(devices),
        time_steps,
    )

    jump_model = get_jump_model(container)

    for d in devices
        ini_val = get_initial_parameter_value(T(), d, event_model)
        name = PSY.get_name(d)
        for t in time_steps
            set_multiplier!(
                parameter_container,
                get_parameter_multiplier(T(), d, event_model),
                name,
                t,
            )
            set_parameter!(
                parameter_container,
                jump_model,
                ini_val,
                name,
                t,
            )
        end
    end
    return
end
