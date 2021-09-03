# So far just the EmulationStore is implemented.
"""
Stores results data for one EmulationModel
"""
mutable struct EmulationStoreData <: ModelStoreData
    duals::Dict{ConstraintKey, DataFrames.DataFrame}
    parameters::Dict{ParameterKey, DataFrames.DataFrame}
    variables::Dict{VariableKey, DataFrames.DataFrame}
    aux_variables::Dict{AuxVarKey, DataFrames.DataFrame}
end

function EmulationStoreData()
    return EmulationStoreData(
        Dict{ConstraintKey, DataFrames.DataFrame}(),
        Dict{ParameterKey, DataFrames.DataFrame}(),
        Dict{VariableKey, DataFrames.DataFrame}(),
        Dict{AuxVarKey, DataFrames.DataFrame}(),
    )
end

"""
Stores simulation data in memory
"""
mutable struct InMemoryModelStore
    data::ModelStoreData
    optimizer_stats::OrderedDict{Dates.DateTime, OptimizerStats}
end

function InMemoryModelStore(::Type{T}) where {T <: ModelStoreData}
    return InMemoryModelStore(T(), OrderedDict{Dates.DateTime, OptimizerStats}())
end

function Base.empty!(store::InMemoryModelStore)
    T = typeof(store.data)
    store.data = T()
    @debug "Emptied the store with data T"
end

Base.isopen(store::InMemoryModelStore) = true
Base.close(store::InMemoryModelStore) = nothing
Base.flush(store::InMemoryModelStore) = nothing

# TODO: Optimizer stats
# function write_optimizer_stats!(
#     store::InMemoryModelStore,
#     model,
#     stats::OptimizerStats,
#     timestamp,
# )
#     store.optimizer_stats[timestamp] = stats
#     return
# end
#
# function read_model_optimizer_stats(
#     store::InMemoryModelStore,
#     model,
#     timestamp,
# )
#     _check_timestamp(store.optimizer_stats, timestamp)
#     return store.optimizer_stats[timestamp]
# end
#
# function read_model_optimizer_stats(store::InMemoryModelStore)
#     stats = [to_namedtuple(x) for x in values(store.optimizer_stats)]
#     return DataFrames.DataFrame(stats)
# end

# Not sure if needed
# function open_store(
#     func::Function,
#     ::Type{InMemoryModelStore},
#     ::AbstractString,  # Unused. Need to match the interface.
#     mode = nothing,
#     filename = nothing,
# )
#     store = InMemoryModelStore()
#     return func(store)
# end

function initialize_model_storage!(
    store::InMemoryModelStore,
    container::OptimizationContainer,
    params::ModelStoreParams,
)
    @debug "initialize_model_storage"

    num_of_executions = get_num_executions(params)
    for type in STORE_CONTAINERS
        field_containers = getfield(container, type)
        store_container = getfield(store.data, type)
        for (key, container) in field_containers
            container_axes = axes(container)
            @debug "Adding $(encode_key_as_string(key)) to InMemoryModelStore"
            if length(container_axes) == 2
                column_names = string.(axes(container)[1])
                store_container[key] = DataFrames.DataFrame(
                    Dict(c => fill(NaN, num_of_executions) for c in column_names),
                )
            elseif length(container_axes) == 1
                store_container[key] = DataFrames.DataFrame(
                    encode_key_as_string(key) => fill(NaN, num_of_executions),
                )
            else
                error("Container structure for $(encode_key_as_string(key)) not supported")
            end
        end
    end

    store.optimizer_stats = OrderedDict{Dates.DateTime, OptimizerStats}()
    @debug "Initialized optimizer_stats_datasets $(get_name(model))"
end

function write_result!(
    store::InMemoryModelStore,
    model_name,
    container_type,
    name,
    timestamp,
    array,
    columns = nothing,
)
    container = getfield(store.data[model_name], container_type)
    container[name][timestamp] = axis_array_to_dataframe(array, columns)
    return
end

function read_result(
    ::Type{DataFrames.DataFrame},
    store::InMemoryModelStore,
    model_name,
    container_type,
    name,
    timestamp::Dates.DateTime,
)
    return read_result(store, model_name, container_type, name, timestamp)
end

function read_result(
    store::InMemoryModelStore,
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
