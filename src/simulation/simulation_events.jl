function apply_simulation_events!(simulation::Simulation)
    sequence = get_sequence(simulation)
    events = get_events(sequence)
    simulation_state = get_simulation_state(simulation)
    for (event, event_model) in events
        @show event_model
        @show check_condition(simulation_state, event_model)
        if check_condition(simulation_state, event_model)
            apply_affect!(simulation_state, event_model)
        end
    end
    error("here run the events")
end

function check_condition(::SimulationState, ::EventModel{<:PSY.Contingency, ContinuousCondition})
    return true
end

function apply_affect!(state::SimulationState, event_model::EventModel{PSY.GeometricDistributionForcedOutage, <:AbstractEventCondition})
    error("here")
    # Put a StateUpdateEvent here
end
