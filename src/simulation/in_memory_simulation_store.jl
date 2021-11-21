"""
Stores simulation data in memory
"""
mutable struct InMemorySimulationStore <: SimulationStore
    params::SimulationStoreParams
    data::OrderedDict{Symbol, DecisionModelOptimizerResults}
    # The key is the model name.
    optimizer_stats::Dict{Symbol, OrderedDict{Dates.DateTime, OptimizerStats}}
end

function InMemorySimulationStore()
    return InMemorySimulationStore(
        SimulationStoreParams(),
        OrderedDict{Symbol, DecisionModelOptimizerResults}(),
        Dict{Symbol, OrderedDict{Dates.DateTime, OptimizerStats}}(),
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
    for model_data in values(store.data)
        for type in STORE_CONTAINERS
            container = getfield(model_data, type)
            for dict in values(container)
                empty!(dict)
            end
        end
    end

    empty!(store.optimizer_stats)
    @debug "Emptied the store"
end

Base.isopen(::InMemorySimulationStore) = true
Base.close(::InMemorySimulationStore) = nothing
Base.flush(::InMemorySimulationStore) = nothing
get_params(store::InMemorySimulationStore) = store.params

list_models(store::InMemorySimulationStore) = keys(store.data)
log_cache_hit_percentages(::InMemorySimulationStore) = nothing

function list_fields(
    store::InMemorySimulationStore,
    model_name::Symbol,
    container_type::Symbol,
)
    container = getfield(store.data[model_name], container_type)
    return keys(container)
end

function write_optimizer_stats!(
    store::InMemorySimulationStore,
    model_name,
    stats::OptimizerStats,
    timestamp::Dates.DateTime,
)
    store.optimizer_stats[Symbol(model_name)][timestamp] = stats
    return
end

function read_model_optimizer_stats(
    store::InMemorySimulationStore,
    ::Int,
    model_name,
    timestamp::Dates.DateTime,
)
    _check_timestamp(store.optimizer_stats, timestamp)
    return store.optimizer_stats[model_name][timestamp]
end

function read_model_optimizer_stats(store::InMemorySimulationStore, model_name)
    stats = [to_namedtuple(x) for x in values(store.optimizer_stats[model_name])]
    return DataFrames.DataFrame(stats)
end

function initialize_model_storage!(
    store::InMemorySimulationStore,
    params,
    model_reqs,
    flush_rules,
)
    store.params = params
    @debug "initialize in memory storage"

    for model_name in keys(store.params.models)
        store.data[model_name] = DecisionModelOptimizerResults()
        for type in STORE_CONTAINERS
            for (name, reqs) in getfield(model_reqs[model_name], type)
                container = getfield(store.data[model_name], type)
                container[name] = OrderedDict{Dates.DateTime, DataFrames.DataFrame}()
            end
        end

        store.optimizer_stats[model_name] = OrderedDict{Dates.DateTime, OptimizerStats}()
        @debug "Initialized optimizer_stats_datasets $model_name"
    end
end

function write_result!(
    store::InMemorySimulationStore,
    model_name,
    container_type,
    name,
    timestamp::Dates.DateTime,
    array,
    columns = nothing,
)
    container = getfield(store.data[model_name], container_type)
    container[name][timestamp] = axis_array_to_dataframe(array, columns)
    return
end

function read_result(
    ::Type{DataFrames.DataFrame},
    store::InMemorySimulationStore,
    model_name,
    container_type,
    name,
    timestamp::Dates.DateTime,
)
    return read_result(store, model_name, container_type, name, timestamp)
end

function read_result(
    store::InMemorySimulationStore,
    model_name,
    container_type,
    name,
    timestamp::Dates.DateTime,
)
    container = getfield(store.data[Symbol(model_name)], container_type)[name]
    _check_timestamp(container, timestamp)
    # Return a copy because callers may mutate it. SimulationProblemResults adds timestamps.
    return copy(container[timestamp], copycols = true)
end

function _check_timestamp(dict::AbstractDict, timestamp::Dates.DateTime)
    if !haskey(dict, timestamp)
        throw(IS.InvalidValue("timestamp = $timestamp is not stored"))
    end
end
