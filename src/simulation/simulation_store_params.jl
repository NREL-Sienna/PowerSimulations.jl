struct SimulationStoreParams
    initial_time::Dates.DateTime
    step_resolution::Dates.Period
    num_steps::Int
    # The key order is the problem execution order.
    models::OrderedDict{Symbol, ModelStoreParams}

    function SimulationStoreParams(initial_time, step_resolution, num_steps, problems)
        new(initial_time, Dates.Millisecond(step_resolution), num_steps, problems)
    end
end

function SimulationStoreParams(initial_time, step_resolution, num_steps)
    return SimulationStoreParams(
        initial_time,
        step_resolution,
        num_steps,
        OrderedDict{Symbol, ModelStoreParams}(),
    )
end

function SimulationStoreParams()
    return SimulationStoreParams(
        Dates.DateTime("1970-01-01T00:00:00"),
        Dates.Millisecond(0),
        0,
        OrderedDict{Symbol, ModelStoreParams}(),
    )
end

get_initial_time(store_params::SimulationStoreParams) = store_params.initial_time
get_problems(store_params::SimulationStoreParams) = store_params.problems
