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
                apply_affect!(simulation, event_model, event, device_types)
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
    simulation::Simulation,
    event_model::EventModel{
        PSY.GeometricDistributionForcedOutage,
        <:AbstractEventCondition,
    },
    event::PSY.GeometricDistributionForcedOutage,
    device_type_maps::Dict{DataType, Set{String}},
)
    sim_state = get_simulation_state(simulation)
    sim_time = get_current_time(simulation)
    rng = get_rng(simulation)
    λ = PSY.get_outage_transition_probability(event)
    mttr = PSY.get_mean_time_to_recovery(event)
    outage_status = Float64(rand(rng, Bernoulli(λ)))
    for (dtype, device_names) in device_type_maps
        if dtype == PSY.RenewableDispatch
            continue
        end
        current_status_data =
            get_system_state_data(sim_state, AvailableStatusParameter(), dtype)
        current_status_values = get_last_recorded_value(current_status_data)
        em_model = get_emulation_model(get_models(simulation))
        em_model_store = get_store_params(em_model)
        for d in device_names
            if current_status_values[d] < 1.0
                continue
            else
                @show d
                @show current_status_values[d] = outage_status
                update_decision_state!(sim_state, ParameterKey(AvailableStatusParameter, dtype), mttr, sim_time, em_model_store)
                # update_decision_state!(sim_state, VariableKey(ActivePowerVariable, dtype), mttr, sim_time, em_model_store)
                error()
            end
        end
    end
    # Put a StateUpdateEvent here
end
