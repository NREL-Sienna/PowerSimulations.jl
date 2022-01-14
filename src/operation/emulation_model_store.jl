"""
Stores results data for one EmulationModel
"""
mutable struct EmulationModelStore <: AbstractModelStore
    duals::Dict{ConstraintKey, ExtendedDataFrame}
    parameters::Dict{ParameterKey, ExtendedDataFrame}
    variables::Dict{VariableKey, ExtendedDataFrame}
    aux_variables::Dict{AuxVarKey, ExtendedDataFrame}
    expressions::Dict{ExpressionKey, ExtendedDataFrame}
    optimizer_stats::OrderedDict{Int, OptimizerStats}
end

function EmulationModelStore()
    return EmulationModelStore(
        Dict{ConstraintKey, ExtendedDataFrame}(),
        Dict{ParameterKey, ExtendedDataFrame}(),
        Dict{VariableKey, ExtendedDataFrame}(),
        Dict{AuxVarKey, ExtendedDataFrame}(),
        Dict{ExpressionKey, ExtendedDataFrame}(),
        OrderedDict{Int, OptimizerStats}(),
    )
end

function Base.empty!(store::EmulationModelStore)
    stype = typeof(store)
    for (name, _) in zip(fieldnames(stype), fieldtypes(stype))
        if name == :last_recorded_row
            store.last_recorded_row = 0
        else
            val = getfield(store, name)
            try
                empty!(val)
            catch
                @error "Base.empty! must be customized for type $stype or skipped"
                rethrow()
            end
        end
    end
end

function Base.isempty(store::EmulationModelStore)
    stype = typeof(store)
    for (name, type) in zip(fieldnames(stype), fieldtypes(stype))
        name == :last_recorded_row && continue
        val = getfield(store, name)
        try
            !isempty(val) && return false
        catch
            @error "Base.isempty must be customized for type $stype or skipped"
            rethrow()
        end
    end

    @assert_op store.last_recorded_row == 0
    return true
end

function initialize_storage!(
    store::EmulationModelStore,
    container::OptimizationContainer,
    params::ModelStoreParams,
)
    num_of_executions = get_num_executions(params)
    for type in STORE_CONTAINERS
        field_containers = getfield(container, type)
        results_container = getfield(store, type)
        for (key, field_container) in field_containers
            @debug "Adding $(encode_key_as_string(key)) to EmulationModelStore" _group =
                LOG_GROUP_MODEL_STORE
            column_names = get_column_names(key, field_container)
            results_container[key] = ExtendedDataFrame(
                OrderedDict(c => fill(NaN, num_of_executions) for c in column_names),
            )
        end
    end
    return
end

function write_next_result!(
    store::EmulationModelStore,
    key::OptimizationContainerKey,
    update_timestamp::Dates.DateTime,
    array::AbstractArray,
)
    df = axis_array_to_dataframe(array, key)
    write_result!(store, key, update_timestamp, df)
    return
end

function write_next_result!(
    store::EmulationModelStore,
    key::OptimizationContainerKey,
    update_timestamp::Dates.DateTime,
    df::Union{DataFrames.DataFrame, DataFrames.DataFrameRow},
)
    container = getfield(store, get_store_container_type(key))
    set_next_rows!(container[key], df)
    set_update_timestamp!(container[key], update_timestamp)
    return
end

function write_result!(
    store::EmulationModelStore,
    name::Symbol,
    key::OptimizationContainerKey,
    index::EmulationModelIndexType,
    update_timestamp::Dates.DateTime,
    array::AbstractArray,
)
    df = axis_array_to_dataframe(array, key)
    write_result!(store, name, key, index, update_timestamp, df)
    return
end

function write_result!(
    store::EmulationModelStore,
    name::Symbol,
    key::OptimizationContainerKey,
    index::EmulationModelIndexType,
    update_timestamp::Dates.DateTime,
    df::DataFrames.DataFrame,
)
    @assert_op size(df)[1] == 1
    write_result!(store, name, key, index, update_timestamp, df[1, :])
    return
end

function write_result!(
    store::EmulationModelStore,
    ::Symbol,
    key::OptimizationContainerKey,
    index::EmulationModelIndexType,
    update_timestamp::Dates.DateTime,
    df_row::DataFrames.DataFrameRow,
)
    container = getfield(store, get_store_container_type(key))
    container[key][index, :] = df_row
    set_update_timestamp!(container[key], update_timestamp)
    return
end

function read_results(
    store::EmulationModelStore,
    ::Symbol,
    key::OptimizationContainerKey,
    index::Union{Int, Nothing} = nothing,
)
    container = getfield(store, get_store_container_type(key))
    # Return a copy because callers may mutate it.
    if isnothing(index)
        return copy(container[key], copycols = true)
    else
        return copy(container[key], copycols = true)[index, :]
    end
end

function get_last_updated_timestamp(
    store::EmulationModelStore,
    ::Symbol,
    key::OptimizationContainerKey,
)
    container = getfield(store, get_store_container_type(key))
    return get_update_timestamp(container[key])
end
function write_optimizer_stats!(
    store::EmulationModelStore,
    stats::OptimizerStats,
    index::EmulationModelIndexType,
)
    @assert !(index in keys(store.optimizer_stats))
    store.optimizer_stats[index] = stats
    return
end

function read_optimizer_stats(store::EmulationModelStore)
    return DataFrames.DataFrame([to_namedtuple(x) for x in values(store.optimizer_stats)])
end

function get_last_recorded_row(x::EmulationModelStore, key::OptimizationContainerKey)
    return get_last_recorded_row(getfield(x, get_store_container_type(key))[key])
end
