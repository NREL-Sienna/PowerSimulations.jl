"""
Stores simulation data in memory
"""
mutable struct InMemorySimulationStore <: SimulationStore
    params::SimulationStoreParams
    dm_data::OrderedDict{Symbol, DecisionModelOptimizerResults}
    em_data::OrderedDict{Symbol, EmulationModelOptimizerResults}
end

function InMemorySimulationStore()
    return InMemorySimulationStore(
        SimulationStoreParams(),
        OrderedDict{Symbol, DecisionModelOptimizerResults}(),
        OrderedDict{Symbol, EmulationModelOptimizerResults}(),
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
    empty!(store.dm_data)
    empty!(store.em_data)
    @debug "Emptied the store" _group = LOG_GROUP_SIMULATION_STORE
end

Base.isopen(::InMemorySimulationStore) = true
Base.close(::InMemorySimulationStore) = nothing
Base.flush(::InMemorySimulationStore) = nothing
get_params(store::InMemorySimulationStore) = store.params

function get_model_params(store::InMemorySimulationStore, model_name::Symbol)
    return get_params(store).models_params[model_name]
end

list_models(store::InMemorySimulationStore) =
    Iterators.flatten((keys(store.dm_data), keys(store.em_data)))
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
    timestamp::Dates.DateTime,
)
    write_optimizer_stats!(store.dm_data[model_name], stats, timestamp)
    return
end

function write_optimizer_stats!(
    store::InMemorySimulationStore,
    model_name,
    stats::OptimizerStats,
    execution::Int,
)
    write_optimizer_stats!(store.em_data[model_name], stats, index)
    return
end

function read_model_optimizer_stats(
    store::InMemorySimulationStore,
    model_name,
    timestamp::Dates.DateTime,
)
    return read_optimizer_stats(store.dm_data[model_name], timestamp)
end

function read_model_optimizer_stats(
    store::InMemorySimulationStore,
    model_name,
    execution::Int,
)
    return read_optimizer_stats(store.em_data[model_name], execution)
end

function initialize_problem_storage!(
    store::InMemorySimulationStore,
    params,
    problem_reqs,
    flush_rules,
)
    store.params = params
    for problem in keys(store.params.models_params)
        store.dm_data[problem] = DecisionModelOptimizerResults()
        for type in STORE_CONTAINERS
            for (name, reqs) in getfield(problem_reqs[problem], type)
                container = getfield(store.dm_data[problem], type)
                container[name] = OrderedDict{Dates.DateTime, DataFrames.DataFrame}()
                @debug "Added $type $name in $problem" _group = LOG_GROUP_SIMULATION_STORE
            end
        end

        # TODO EmulationModel: how do we differentiate DM and EM?
    end
end

function write_result!(
    store::InMemorySimulationStore,
    model_name,
    key::OptimizationContainerKey,
    timestamp::Dates.DateTime,
    array,
    columns = nothing,
)
    write_result!(store.dm_data[model_name], key, timestamp, array, columns)
    return
end

function read_result(
    ::Type{DataFrames.DataFrame},
    store::InMemorySimulationStore,
    model_name,
    key,
    timestamp::Dates.DateTime,
)
    return read_result(store, model_name, key, timestamp)
end

function read_result(
    store::InMemorySimulationStore,
    model_name,
    key,
    timestamp::Dates.DateTime,
)
    return read_results(store.dm_data[model_name], key, timestamp)
end

# Note that this function is not type-stable.
function _get_model_results(store::InMemorySimulationStore, model_name::Symbol)
    if model_name in keys(store.dm_data)
        results = store.dm_data
    elseif model_name in keys(store.em_data)
        results = store.em_data
    else
        error("model name $model_name is not stored")
    end

    return results[model_name]
end
