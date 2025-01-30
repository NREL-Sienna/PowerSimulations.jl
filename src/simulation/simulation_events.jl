function apply_simulation_events!(simulation::Simulation)
    sequence = get_sequence(simulation)
    events = get_events(sequence)
    simulation_state = get_simulation_state(simulation)
    for event_model in events
        if check_condition(simulation_state, event_model)
            @warn "Condition evaluated to true at time $(get_current_time(simulation))"
            # TODO: for other event categories we need to do something else
            em_model = get_emulation_model(get_models(simulation))
            sys = get_system(em_model)
            model_name = get_name(em_model)
            for (event_uuid, device_type_maps) in
                event_model.attribute_device_map[model_name]
                event = PSY.get_supplemental_attribute(sys, event_uuid)
                @warn "Applying affect for $device_type_maps"
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

function check_condition(
    simulation_state::SimulationState,
    event_model::EventModel{<:PSY.Contingency, PresetTimeCondition},
)
    condition = get_event_condition(event_model)
    event_times = get_time_stamps(condition)
    current_time = get_current_time(simulation_state)
    if current_time in event_times
        return true
    else
        return false
    end
end

function check_condition(
    simulation_state::SimulationState,
    event_model::EventModel{<:PSY.Contingency, StateVariableValueCondition},
)
    condition = get_event_condition(event_model)
    variable_type = get_variable_type(condition)
    device_type = get_device_type(condition)
    device_name = get_device_name(condition)
    event_value = get_value(condition)

    system_value =
        get_system_state_data(simulation_state, variable_type, device_type).values[
            device_name,
            1,
        ]
    if isapprox(system_value, event_value; atol = ABSOLUTE_TOLERANCE)
        return true
    else
        return false
    end
end

function check_condition(
    simulation_state::SimulationState,
    event_model::EventModel{<:PSY.Contingency, DiscreteEventCondition},
)
    condition = get_event_condition(event_model)
    f = condition.condition_function
    if f(simulation_state)
        return true
    else
        return false
    end
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
        # Order is required here. The AvailableStatusChangeParameter needs to be updated first
        # to indicate that there is a change in the othe parameters
        update_system_state!(
            sim_state,
            ParameterKey(AvailableStatusChangeParameter, dtype),
            device_names,
            event,
            sim_time,
            rng,
        )
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
        # Order is required here too AvailableStatusChangeParameter needs to
        # go first to indicate that there is a change in the other values
        update_decision_state!(
            sim_state,
            ParameterKey(AvailableStatusChangeParameter, dtype),
            device_names,
            event,
            sim_time,
            em_model_store,
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
