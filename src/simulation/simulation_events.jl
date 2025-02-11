function apply_simulation_events!(simulation::Simulation)
    sequence = get_sequence(simulation)
    events = get_events(sequence)
    simulation_state = get_simulation_state(simulation)
    for event_model in events
        extend_event_parameters!(simulation, event_model)
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

function extend_event_parameters!(simulation::Simulation, event_model)
    sequence = get_sequence(simulation)
    sim_state = get_simulation_state(simulation)
    em_model = get_emulation_model(get_models(simulation))
    model_name = get_name(em_model)
    for (event_uuid, device_type_maps) in
        event_model.attribute_device_map[model_name]
        sim_time = get_current_time(simulation)
        for (dtype, device_names) in device_type_maps
            if dtype == PSY.RenewableDispatch
                continue
            end
            em_model = get_emulation_model(get_models(simulation))
            status_change_countdown_data = get_decision_state_data(
                sim_state,
                ParameterKey(AvailableStatusChangeCountdownParameter, dtype),
            )
            status_data = get_decision_state_data(
                sim_state,
                ParameterKey(AvailableStatusParameter, dtype),
            )
            state_timestamps = status_data.timestamps
            state_data_index = find_timestamp_index(state_timestamps, sim_time)
            if state_data_index == 1
                for name in device_names
                    if status_change_countdown_data.values[name, 1] > 1.0
                        starting_count = status_change_countdown_data.values[name, 1]
                        for i in 1:length(status_change_countdown_data.values[name, :])
                            countdown_val = max(starting_count + 1 - i, 0.0)
                            if countdown_val == 0.0
                                status_val = 1.0
                            else
                                status_val = 0.0
                            end
                            status_change_countdown_data.values[name, i] = countdown_val
                            status_data.values[name, i] = status_val
                        end
                    end
                end
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
    event_model::EventModel{
        T,
        <:AbstractEventCondition,
    },
    event::T,
    device_type_maps::Dict{DataType, Set{String}},
) where {T <: PSY.Contingency}
    sim_state = get_simulation_state(simulation)
    sim_time = get_current_time(simulation)
    rng = get_rng(simulation)
    for (dtype, device_names) in device_type_maps
        if dtype == PSY.RenewableDispatch
            continue
        end
        em_model = get_emulation_model(get_models(simulation))
        em_model_store = get_store_params(em_model)
        # Order is required here. The AvailableStatusChangeCountdownParameter needs to be updated first
        # to indicate that there is a change in the othe parameters
        update_system_state!(
            sim_state,
            ParameterKey(AvailableStatusChangeCountdownParameter, dtype),
            device_names,
            event,
            event_model,
            sim_time,
            rng,
        )
        update_system_state!(
            sim_state,
            ParameterKey(AvailableStatusParameter, dtype),
            device_names,
            event,
            event_model,
            sim_time,
            rng,
        )
        update_system_state!(
            sim_state,
            VariableKey(ActivePowerVariable, dtype),
            device_names,
            event,
            event_model,
            sim_time,
            rng,
        )
        update_system_state!(
            sim_state,
            VariableKey(OnVariable, dtype),
            device_names,
            event,
            event_model,
            sim_time,
            rng,
        )
        # Order is required here too AvailableStatusChangeCountdownParameter needs to
        # go first to indicate that there is a change in the other values
        update_decision_state!(
            sim_state,
            ParameterKey(AvailableStatusChangeCountdownParameter, dtype),
            device_names,
            event,
            event_model,
            sim_time,
            em_model_store,
        )
        update_decision_state!(
            sim_state,
            ParameterKey(AvailableStatusParameter, dtype),
            device_names,
            event,
            event_model,
            sim_time,
            em_model_store,
        )
        update_decision_state!(
            sim_state,
            VariableKey(ActivePowerVariable, dtype),
            device_names,
            event,
            event_model,
            sim_time,
            em_model_store,
        )
        update_decision_state!(
            sim_state,
            VariableKey(OnVariable, dtype),
            device_names,
            event,
            event_model,
            sim_time,
            em_model_store,
        )
    end
    # Put a StateUpdateEvent here
end
