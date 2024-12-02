function apply_simulation_events!(simulation::Simulation)
    sequence = get_sequence(simulation)
    events = get_events(sequence)
    simulation_state = get_simulation_state(simulation)
    for event_model in events
        if check_condition(simulation_state, event_model)
            # TODO: for other event categories we need to do something else
            em_model = get_emulation_model(get_models(simulation))
            sys = get_system(em_model)
            model_name = get_name(em_model)
            for (event_uuid, device_type_maps) in
                event_model.attribute_device_map[model_name]
                event = PSY.get_supplemental_attribute(sys, event_uuid)
                apply_affect!(simulation, event_model, event, device_type_maps)
            end
        end
    end
end

function check_condition(
    ::SimulationState,
    ::EventModel{<:PSY.Contingency, ContinuousCondition},
)
    return true
end

function apply_affect!(
    simulation::Simulation,
    ::EventModel{
        PSY.GeometricDistributionForcedOutage,
        <:AbstractEventCondition,
    },
    event::PSY.GeometricDistributionForcedOutage,
    device_type_maps::Dict{DataType, Set{String}},
)
    sim_state = get_simulation_state(simulation)
    sim_time = get_current_time(simulation)
    rng = get_rng(simulation)
    for (dtype, device_names) in device_type_maps
        if dtype == PSY.RenewableDispatch
            continue
        end
        em_model = get_emulation_model(get_models(simulation))
        em_model_store = get_store_params(em_model)
        update_system_state!(
            sim_state,
            ParameterKey(AvailableStatusParameter, dtype),
            device_names,
            event,
            sim_time,
            rng,
        )
        update_system_state!(
            sim_state,
            VariableKey(ActivePowerVariable, dtype),
            device_names,
            event,
            sim_time,
            rng,
        )
        update_system_state!(
            sim_state,
            VariableKey(OnVariable, dtype),
            device_names,
            event,
            sim_time,
            rng,
        )
        update_decision_state!(
            sim_state,
            ParameterKey(AvailableStatusParameter, dtype),
            device_names,
            event,
            sim_time,
            em_model_store,
        )
        update_decision_state!(
            sim_state,
            VariableKey(ActivePowerVariable, dtype),
            device_names,
            event,
            sim_time,
            em_model_store,
        )
        update_decision_state!(
            sim_state,
            VariableKey(OnVariable, dtype),
            device_names,
            event,
            sim_time,
            em_model_store,
        )
    end
    # Put a StateUpdateEvent here
end
