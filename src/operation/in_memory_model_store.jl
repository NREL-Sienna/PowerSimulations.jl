"""
Stores simulation data in memory
"""
mutable struct InMemoryModelStore{T <: AbstractModelOptimizerResults}
    data::T
end

function InMemoryModelStore(::Type{T}) where {T <: AbstractModelOptimizerResults}
    return InMemoryModelStore(T())
end

# TBD: Implementation depending on what the call need is. Needs to make sure it is safe.
# Possible use case: Call Run on EmulationModel without calling build again
function Base.empty!(
    store::InMemoryModelStore{T},
) where {T <: AbstractModelOptimizerResults}
    store.data = T()
    @debug "Emptied the store with data $T" _group = LOG_GROUP_IN_MEMORY_MODEL_STORE
end

Base.isopen(store::InMemoryModelStore) = true
Base.close(store::InMemoryModelStore) = nothing
Base.flush(store::InMemoryModelStore) = nothing

function Base.isempty(
    store::InMemoryModelStore{T},
) where {T <: AbstractModelOptimizerResults}
    empty = true
    for field in fieldnames(T)
        value_container = getfield(store.data, field)
        empty = isempty(value_container)
        !empty && break
    end

    return empty
end

function write_result!(
    store::InMemoryModelStore,
    key::OptimizationContainerKey,
    index,
    array,
    columns,
)
    return write_result!(store.data, key, index, array, columns)
end

function read_results(
    ::Type{DataFrames.DataFrame},
    store::InMemoryModelStore,
    key::OptimizationContainerKey,
    index = nothing,
)
    return read_results(store, key, index)
end

function read_results(store::InMemoryModelStore, key, index = nothing)
    return read_results(store.data, key, index)
end

function write_optimizer_stats!(store::InMemoryModelStore, stats::OptimizerStats, index)
    write_optimizer_stats!(store.data, stats, index)
    return
end

function read_optimizer_stats(store::InMemoryModelStore)
    return read_optimizer_stats(store.data)
end

function initialize_storage!(
    store::InMemoryModelStore{EmulationModelOptimizerResults},
    container::OptimizationContainer,
    params::ModelStoreParams,
)
    num_of_executions = get_num_executions(params)
    for type in STORE_CONTAINERS
        field_containers = getfield(container, type)
        store_container = getfield(store.data, type)
        for (key, field_container) in field_containers
            container_axes = axes(field_container)
            @debug "Adding $(encode_key_as_string(key)) to InMemoryModelStore" _group =
                LOG_GROUP_IN_MEMORY_MODEL_STORE
            if length(container_axes) == 2
                if type == STORE_CONTAINER_PARAMETERS
                    column_names = string.(get_parameter_array(field_container).axes[1])
                else
                    column_names = string.(axes(field_container)[1])
                end
                store_container[key] = DataFrames.DataFrame(
                    OrderedDict(c => fill(NaN, num_of_executions) for c in column_names),
                )
            elseif length(container_axes) == 1
                @assert_op container_axes[1] == get_time_steps(container)
                store_container[key] =
                    DataFrames.DataFrame("System" => fill(NaN, num_of_executions))
            else
                error("Container structure for $(encode_key_as_string(key)) not supported")
            end
        end
    end
end

function initialize_storage!(
    store::InMemoryModelStore{DecisionModelOptimizerResults},
    container::OptimizationContainer,
    params::ModelStoreParams,
)
    num_of_executions = get_num_executions(params)
    time_steps_count = get_time_steps(container)[end]
    initial_time = get_initial_time(container)
    model_interval = get_interval(params)
    for type in STORE_CONTAINERS
        field_containers = getfield(container, type)
        store_container = getfield(store.data, type)
        for (key, field_container) in field_containers
            container_axes = axes(field_container)
            @debug "Adding $(encode_key_as_string(key)) to InMemoryModelStore" _group =
                LOG_GROUP_IN_MEMORY_MODEL_STORE
            store_container[key] = OrderedDict{Dates.DateTime, DataFrames.DataFrame}()
            for timestamp in
                range(initial_time, step = model_interval, length = num_of_executions)
                if length(container_axes) == 2
                    if type == STORE_CONTAINER_PARAMETERS
                        column_names = string.(get_parameter_array(field_container).axes[1])
                    else
                        column_names = string.(axes(field_container)[1])
                    end

                    store_container[key][timestamp] = DataFrames.DataFrame(
                        OrderedDict(c => fill(NaN, time_steps_count) for c in column_names),
                    )
                elseif length(container_axes) == 1
                    store_container[key][timestamp] = DataFrames.DataFrame(
                        encode_key_as_string(key) => fill(NaN, time_steps_count),
                    )
                else
                    error(
                        "Container structure for $(encode_key_as_string(key)) not supported",
                    )
                end
            end
        end
    end
end

function list_keys(store::InMemoryModelStore, container_type)
    container = getfield(store.data, container_type)
    return collect(keys(container))
end

function get_variable_value(
    store::InMemoryModelStore,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    return store.data.variables[VariableKey(T, U)]
end

function get_aux_variable_value(
    store::InMemoryModelStore,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return store.data.aux_variables[AuxVarKey(T, U)]
end

function get_dual_value(
    store::InMemoryModelStore,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return store.data.duals[ConstraintKey(T, U)]
end

function get_parameter_value(
    store::InMemoryModelStore,
    ::T,
    ::Type{U},
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return store.data.parameters[ParameterKey(T, U)]
end

# TODO DT: Jose, do we need this for DecisionModel?
get_last_recorded_row(x::InMemoryModelStore) = get_last_recorded_row(x.data)
set_last_recorded_row!(x::InMemoryModelStore, y) = set_last_recorded_row!(x.data, y)
