"""
Stores simulation data in memory
"""
mutable struct InMemorySimulationStore <: SimulationStore
    params::SimulationStoreParams
    dm_data::OrderedDict{Symbol, DecisionModelStore}
    em_data::EmulationModelStore
end

function InMemorySimulationStore()
    return InMemorySimulationStore(
        SimulationStoreParams(),
        OrderedDict{Symbol, DecisionModelStore}(),
        EmulationModelStore(),
    )
end

function open_store(
    func::Function,
    ::Type{InMemorySimulationStore},
    directory::AbstractString,  # Unused. Need to match the interface.
    mode = nothing,
    filename = nothing,
)
    store = InMemorySimulationStore()
    return func(store)
end

function Base.empty!(store::InMemorySimulationStore)
    for val in values(get_dm_data(store))
        empty!(val)
    end
    empty!(get_em_data(store))
    @debug "Emptied the store" _group = LOG_GROUP_SIMULATION_STORE
    return
end

Base.isopen(::InMemorySimulationStore) = true
Base.close(::InMemorySimulationStore) = nothing
Base.flush(::InMemorySimulationStore) = nothing
get_params(store::InMemorySimulationStore) = store.params

function get_decision_model_params(store::InMemorySimulationStore, model_name::Symbol)
    return get_params(store).decision_models_params[model_name]
end

list_models(x::InMemorySimulationStore) = collect(keys(x.dm_data))
# TODO EmulationModel: this interface is TBD
#list_models(x::InMemorySimulationStore) = vcat(collect(keys(x.dm_data)), [x.em_data])
log_cache_hit_percentages(::InMemorySimulationStore) = nothing

function list_fields(
    store::InMemorySimulationStore,
    model_name::Symbol,
    container_type::Symbol,
)
    return list_fields(_get_model_results(store, model_name), container_type)
end

function write_optimizer_stats!(
    store::InMemorySimulationStore,
    model_name,
    stats::OptimizerStats,
    index::DECISION_MODEL_INDEX,
)
    write_optimizer_stats!(get_dm_data(store)[model_name], stats, index)
    return
end

function write_optimizer_stats!(
    store::InMemorySimulationStore,
    stats::OptimizerStats,
    index::EMULATION_MODEL_INDEX,
)
    write_optimizer_stats!(get_em_data(store), stats, index)
    return
end

function write_result!(
    store::InMemorySimulationStore,
    model_name::Symbol,
    key::OptimizationContainerKey,
    index::DECISION_MODEL_INDEX,
    array,
)
    write_result!(get_dm_data(store)[model_name], model_name, key, index, array)
    return
end

function write_result!(
    store::InMemorySimulationStore,
    model_name::Symbol,
    key::OptimizationContainerKey,
    index::EMULATION_MODEL_INDEX,
    array,
)
    write_result!(get_em_data(store), model_name, key, index, array)
    return
end

function read_optimizer_stats(store::InMemorySimulationStore, model_name)
    # TODO EmulationModel: this interface is TBD
    return read_optimizer_stats(get_dm_data(store)[model_name])
end

function initialize_problem_storage!(
    store::InMemorySimulationStore,
    params::SimulationStoreParams,
    dm_problem_reqs::Dict{Symbol, SimulationModelStoreRequirements},
    em_problem_reqs::SimulationModelStoreRequirements,
    ::CacheFlushRules,
)
    store.params = params
    for problem in keys(store.params.decision_models_params)
        get_dm_data(store)[problem] = DecisionModelStore()
        for type in STORE_CONTAINERS
            for (name, reqs) in getfield(dm_problem_reqs[problem], type)
                container = getfield(get_dm_data(store)[problem], type)
                container[name] = OrderedDict{Dates.DateTime, DataFrames.DataFrame}()
                @debug "Added $type $name in $problem" _group = LOG_GROUP_SIMULATION_STORE
            end
        end
    end

    for type in STORE_CONTAINERS
        for (name, reqs) in getfield(em_problem_reqs, type)
            container = getfield(get_em_data(store), type)
            container[name] = DataFrames.DataFrame(
                OrderedDict(c => fill(NaN, reqs["dims"][1]) for c in reqs["columns"]),
            )
            @debug "Added $type $name in emulation store" _group =
                LOG_GROUP_SIMULATION_STORE
        end
    end

    return
end

function read_result(
    ::Type{DataFrames.DataFrame},
    store::InMemorySimulationStore,
    model_name::Symbol,
    key::OptimizationContainerKey,
    index::DECISION_MODEL_INDEX,
)
    return read_results(get_dm_data(store)[model_name], key, index)
end

function read_result(
    ::Type{DataFrames.DataFrame},
    store::InMemorySimulationStore,
    ::Symbol,
    key::OptimizationContainerKey,
    index::EMULATION_MODEL_INDEX,
)
    return read_results(get_em_data(store), key, index)
end

# Note that this function is not type-stable.
function _get_model_results(store::InMemorySimulationStore, model_name::Symbol)
    if model_name in keys(get_dm_data(store))
        results = get_dm_data(store)
    else
        # TODO EmulationModel: this interface is TBD
        error("model name $model_name is not stored")
    end

    return results[model_name]
end

function write_optimizer_stats!(
    store::InMemorySimulationStore,
    model::DecisionModel,
    index::DECISION_MODEL_INDEX,
)
    stats = get_optimizer_stats(model)
    dm_data = get_dm_data(store)
    write_optimizer_stats!(dm_data[get_name(model)], stats, index)
    return
end

function write_optimizer_stats!(
    store::InMemorySimulationStore,
    model::EmulationModel,
    index::EMULATION_MODEL_INDEX,
)
    stats = get_optimizer_stats(model)
    em_data = get_em_data(store)
    write_optimizer_stats!(em_data, stats, index)
    return
end
