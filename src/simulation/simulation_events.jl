function apply_simulation_events!(simulation::Simulation)
    sequence = get_sequence(simulation)
    events = get_events(sequence)
    simulation_state = get_simulation_state(simulation)
    for (event, event_model) in events
        @show event_model
        @show check_condition(simulation_state, event_model)
        if check_condition(simulation_state, event_model)
            apply_affect!(simulation_state, event_model, get_rng(simulation))
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
    rng::AbstractRNG,
)
    current_status_data =
        get_system_state_data(state, AvailableStatusParameter, ThermalStandard)
    current_status_values = get_last_recorded_value(current_status_data)
    devices = axes(current_status_values)
    λ = 0.9
    for d in devices
        if current_status_value[d] < 1.0
            continue
        else
            @show current_status_value[d] = rand(rng, Bernoulli(λ))
        end
    end
    error()
    # Put a StateUpdateEvent here
end
