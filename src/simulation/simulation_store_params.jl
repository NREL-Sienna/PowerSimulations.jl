struct SimulationStoreParams
    initial_time::Dates.DateTime
    step_resolution::Dates.Millisecond
    num_steps::Int
    # The key order is the problem execution order.
    decision_models_params::OrderedDict{Symbol, IS.ModelStoreParams}
    emulation_model_params::OrderedDict{Symbol, IS.ModelStoreParams}

    function SimulationStoreParams(
        initial_time::Dates.DateTime,
        step_resolution::Dates.Period,
        num_steps::Int,
        decision_models_params::OrderedDict{Symbol, IS.ModelStoreParams},
        emulation_model_params::OrderedDict,
    )
        new(
            initial_time,
            Dates.Millisecond(step_resolution),
            num_steps,
            decision_models_params,
            emulation_model_params,
        )
    end
end

function SimulationStoreParams(initial_time, step_resolution, num_steps)
    return SimulationStoreParams(
        initial_time,
        step_resolution,
        num_steps,
        OrderedDict{Symbol, IS.ModelStoreParams}(),
        OrderedDict{Symbol, IS.ModelStoreParams}(),
    )
end

function SimulationStoreParams()
    return SimulationStoreParams(
        Dates.DateTime("1970-01-01T00:00:00"),
        Dates.Millisecond(0),
        0,
        OrderedDict{Symbol, IS.ModelStoreParams}(),
        OrderedDict{Symbol, IS.ModelStoreParams}(),
    )
end

get_initial_time(store_params::SimulationStoreParams) = store_params.initial_time

function get_decision_model_params(store_params::SimulationStoreParams, model_name::Symbol)
    return store_params.decision_models_params[model_name]
end

function get_emulation_model_params(store_params::SimulationStoreParams)
    # We currently only store one em_model dataset in the store
    @assert_op length(store_params.emulation_model_params) == 1
    return first(values(store_params.emulation_model_params))
end
