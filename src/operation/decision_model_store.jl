"""
Stores results data for one DecisionModel
"""
mutable struct DecisionModelStore <: AbstractModelStore
    duals::Dict{ConstraintKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    parameters::Dict{ParameterKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    variables::Dict{VariableKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    aux_variables::Dict{AuxVarKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    expressions::Dict{ExpressionKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    optimizer_stats::OrderedDict{Dates.DateTime, OptimizerStats}
end

function DecisionModelStore()
    return DecisionModelStore(
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
        OrderedDict{Dates.DateTime, OptimizerStats}(),
    )
end

function initialize_storage!(
    store::DecisionModelStore,
    container::OptimizationContainer,
    params::ModelStoreParams,
)
    num_of_executions = get_num_executions(params)
    time_steps_count = get_time_steps(container)[end]
    initial_time = get_initial_time(container)
    model_interval = get_interval(params)
    for type in STORE_CONTAINERS
        field_containers = getfield(container, type)
        results_container = getfield(store, type)
        for (key, field_container) in field_containers
            !should_write_resulting_value(key) && continue
            @debug "Adding $(encode_key_as_string(key)) to DecisionModelStore" _group =
                LOG_GROUP_MODEL_STORE
            results_container[key] = OrderedDict{Dates.DateTime, DataFrames.DataFrame}()
            column_names = get_column_names(key, field_container)
            for timestamp in
                range(initial_time; step = model_interval, length = num_of_executions)
                results_container[key][timestamp] = DataFrames.DataFrame(
                    OrderedDict(c => fill(NaN, time_steps_count) for c in column_names),
                )
            end
        end
    end
end

function write_result!(
    store::DecisionModelStore,
    name::Symbol,
    key::OptimizationContainerKey,
    index::DecisionModelIndexType,
    update_timestamp::Dates.DateTime,
    array::AbstractArray,
)
    df = axis_array_to_dataframe(array, key)
    write_result!(store, name, key, index, update_timestamp, df)
    return
end

function write_result!(
    store::DecisionModelStore,
    ::Symbol,
    key::OptimizationContainerKey,
    index::DecisionModelIndexType,
    update_timestamp::Dates.DateTime,
    df::Union{DataFrames.DataFrame, DataFrames.DataFrameRow},
)
    container = getfield(store, get_store_container_type(key))
    container[key][index] = df
    return
end

function read_results(
    store::DecisionModelStore,
    key::OptimizationContainerKey;
    index::Union{DecisionModelIndexType, Nothing} = nothing,
)
    container = getfield(store, get_store_container_type(key))
    data = container[key]
    if isnothing(index)
        @assert length(data) == 1
        index = first(keys(data))
    end

    # Return a copy because callers may mutate it.
    return copy(data[index]; copycols = true)
end

function write_optimizer_stats!(
    store::DecisionModelStore,
    stats::OptimizerStats,
    index::DecisionModelIndexType,
)
    if index in keys(store.optimizer_stats)
        @warn "Overwriting optimizer stats"
    end
    store.optimizer_stats[index] = stats
    return
end

function read_optimizer_stats(store::DecisionModelStore)
    stats = [to_namedtuple(x) for x in values(store.optimizer_stats)]
    df = DataFrames.DataFrame(stats)
    DataFrames.insertcols!(df, 1, :DateTime => keys(store.optimizer_stats))
    return df
end
