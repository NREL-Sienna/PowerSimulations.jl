# So far just the EmulationStore is implemented.

"""
Stores results data for one DecisionModel
"""
mutable struct DecisionModelOptimizerResults <: AbstractModelOptimizerResults
    duals::Dict{ConstraintKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    parameters::Dict{ParameterKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    variables::Dict{VariableKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    aux_variables::Dict{AuxVarKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    expressions::Dict{ExpressionKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
end

function DecisionModelOptimizerResults()
    return DecisionModelOptimizerResults(
        Dict{
            ConstraintKey,
            Dict{ConstraintKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}},
        }(),
        Dict{
            ParameterKey,
            Dict{ParameterKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}},
        }(),
        Dict{
            VariableKey,
            Dict{VariableKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}},
        }(),
        Dict{
            AuxVarKey,
            Dict{ConstraintKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}},
        }(),
        Dict{
            AuxVarKey,
            Dict{ExpressionKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}},
        }(),
    )
end

"""
Stores results data for one EmulationModel
"""
mutable struct EmulationModelOptimizerResults <: AbstractModelOptimizerResults
    last_recorded_row::Int
    duals::Dict{ConstraintKey, DataFrames.DataFrame}
    parameters::Dict{ParameterKey, DataFrames.DataFrame}
    variables::Dict{VariableKey, DataFrames.DataFrame}
    aux_variables::Dict{AuxVarKey, DataFrames.DataFrame}
    expressions::Dict{ExpressionKey, DataFrames.DataFrame}
end

function EmulationModelOptimizerResults()
    return EmulationModelOptimizerResults(
        0,
        Dict{ConstraintKey, DataFrames.DataFrame}(),
        Dict{ParameterKey, DataFrames.DataFrame}(),
        Dict{VariableKey, DataFrames.DataFrame}(),
        Dict{AuxVarKey, DataFrames.DataFrame}(),
        Dict{ExpressionKey, DataFrames.DataFrame}(),
    )
end

"""
Stores simulation data in memory
"""
mutable struct InMemoryModelStore{T <: AbstractModelOptimizerResults}
    data::T
    optimizer_stats::OrderedDict{Int, OptimizerStats}
end

function InMemoryModelStore(::Type{T}) where {T <: AbstractModelOptimizerResults}
    return InMemoryModelStore(T(), OrderedDict{Int, OptimizerStats}())
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
    end

    return empty
end

function write_optimizer_stats!(store::InMemoryModelStore, stats::OptimizerStats, execution)
    store.optimizer_stats[execution] = stats
    return
end

function read_optimizer_stats(store::InMemoryModelStore)
    stats = [to_namedtuple(x) for x in values(store.optimizer_stats)]
    return DataFrames.DataFrame(stats)
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

    store.optimizer_stats = OrderedDict{Dates.DateTime, OptimizerStats}()
    @debug "Initialized optimizer_stats_datasets $(get_name(model))" _group =
        LOG_GROUP_IN_MEMORY_MODEL_STORE
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

    store.optimizer_stats = OrderedDict{Dates.DateTime, OptimizerStats}()
    @debug "Initialized optimizer_stats_datasets $(get_name(model))" _group =
        LOG_GROUP_IN_MEMORY_MODEL_STORE
end

function list_keys(store::InMemoryModelStore, container_type)
    container = getfield(store.data, container_type)
    return collect(keys(container))
end

function write_result!(
    store::InMemoryModelStore{EmulationModelOptimizerResults},
    field::Symbol,
    key::OptimizationContainerKey,
    execution::Int,
    array,
    columns,
)
    container = getfield(store.data, field)
    df = axis_array_to_dataframe(array, columns)
    container[key][execution, :] = df[1, :]
    return
end

function write_result!(
    store::InMemoryModelStore{DecisionModelOptimizerResults},
    field::Symbol,
    key::OptimizationContainerKey,
    timestamp::Dates.DateTime,
    array,
    columns,
)
    container = getfield(store.data, field)
    df = axis_array_to_dataframe(array, columns)
    container[key][timestamp] = df
    return
end

function read_results(store::InMemoryModelStore, container_type::Symbol, key)
    return read_results(DataFrames.DataFrame, store, container_type, key)
end

function read_results(
    ::Type{DataFrames.DataFrame},
    store::InMemoryModelStore{EmulationModelOptimizerResults},
    container_type::Symbol,
    key::OptimizationContainerKey,
)
    container = getfield(store.data, container_type)
    # Return a copy because callers may mutate it.
    return copy(container[key], copycols = true)
end

function read_results(
    ::Type{DataFrames.DataFrame},
    store::InMemoryModelStore{DecisionModelOptimizerResults},
    container_type::Symbol,
    key::OptimizationContainerKey,
)
    container = getfield(store.data, container_type)
    @assert length(container[key]) == 1
    # Return a copy because callers may mutate it.
    return copy(first(values(container[key])), copycols = true)
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
