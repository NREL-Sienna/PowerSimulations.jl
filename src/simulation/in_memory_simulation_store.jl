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
    for val in values(store.dm_data)
        empty!(val)
    end
    empty!(store.em_data)
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
    timestamp::Dates.DateTime,
)
    write_optimizer_stats!(store.dm_data[model_name], stats, timestamp)
    return
end

function write_optimizer_stats!(
    store::InMemorySimulationStore,
    stats::OptimizerStats,
    execution::Int,
)
    write_optimizer_stats!(store.em_data, stats, execution)
    return
end

function read_optimizer_stats(store::InMemorySimulationStore, model_name)
    # TODO EmulationModel: this interface is TBD
    return read_optimizer_stats(store.dm_data[model_name])
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
        store.dm_data[problem] = DecisionModelStore()
        for type in STORE_CONTAINERS
            for (name, reqs) in getfield(dm_problem_reqs[problem], type)
                container = getfield(store.dm_data[problem], type)
                container[name] = OrderedDict{Dates.DateTime, DataFrames.DataFrame}()
                @debug "Added $type $name in $problem" _group = LOG_GROUP_SIMULATION_STORE
            end
        end
    end

    for type in STORE_CONTAINERS
        for (name, reqs) in getfield(em_problem_reqs, type)
            container = getfield(store.em_data, type)
            container[name] = DataFrames.DataFrame(
                OrderedDict(c => fill(NaN, reqs["dims"][1]) for c in reqs["columns"]),
            )
            @debug "Added $type $name in emulation store" _group =
                LOG_GROUP_SIMULATION_STORE
        end
    end

    return
end

function write_result!(
    store::InMemorySimulationStore,
    model_name,
    key::OptimizationContainerKey,
    timestamp::Dates.DateTime,
    array,
)
    write_result!(store.dm_data[model_name], key, timestamp, array)
    return
end

function write_result!(
    store::InMemorySimulationStore,
    key::OptimizationContainerKey,
    execution::Int,
    array,
)
    write_result!(store.em_data, key, execution, array)
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
    else
        # TODO EmulationModel: this interface is TBD
        error("model name $model_name is not stored")
    end

    return results[model_name]
end
