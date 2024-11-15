function apply_simulation_events!(simulation::Simulation)
    sequence = get_sequence(simulation)
    events = get_events(sequence)
    simulation_state = get_simulation_state(simulation)
    # TODO: Undo once we have the caching properly implemented
    for event_model in events
        @show "new event"
        if check_condition(simulation_state, event_model)
            # TODO: for other event categories we need to do something else
            em_model = get_emulation_model(get_models(simulation))
            sys = get_system(em_model)
            model_name = get_name(em_model)
            @show event_model.attribute_device_map[model_name]
            for (event_uuid, device_types) in event_model.attribute_device_map[model_name]
                @show event_uuid
                event = PSY.get_supplemental_attribute(sys, event_uuid)
                λ = PSY.get_outage_transition_probability(event)
                parameter_value = Float64(rand(get_rng(simulation), Bernoulli(λ)))
                apply_affect!(simulation_state, event_model, parameter_value, device_types)
            end
        end
    end
    error("here run the events")
end

function check_condition(
    ::SimulationState,
    ::EventModel{<:PSY.Contingency, ContinuousCondition},
)
    return true
end

function apply_affect!(
    state::SimulationState,
    event_model::EventModel{
        PSY.GeometricDistributionForcedOutage,
        <:AbstractEventCondition,
    },
    parameter_value::Float64,
    device_types::Set{DataType},
)
    for dtype in [PSY.ThermalStandard] #device_types
        current_status_data =
            get_system_state_data(state, AvailableStatusParameter(), dtype)
        current_status_values = get_last_recorded_value(current_status_data)
        device_names = axes(current_status_values)[1]
        for d in device_names
            if current_status_values[d] < 1.0
                continue
            else
                @show d
                @show current_status_values[d] = parameter_value
            end
        end
    end
    # Put a StateUpdateEvent here
end
