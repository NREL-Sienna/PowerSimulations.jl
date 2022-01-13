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

function write_result!(
    data::EmulationModelStore,
    name::Symbol,
    key::OptimizationContainerKey,
    index::EmulationModelIndexType,
    array::AbstractArray,
)
    df = axis_array_to_dataframe(array, key)
    write_result!(data, name, key, index, df)
    return
end

function write_result!(
    data::EmulationModelStore,
    ::Symbol,
    key::OptimizationContainerKey,
    index::EmulationModelIndexType,
    df::Union{DataFrames.DataFrame, DataFrames.DataFrameRow},
)
    container = getfield(data, get_store_container_type(key))
    set_next_rows!(container[key], df)
    return
end

function read_results(
    data::EmulationModelStore,
    ::Symbol,
    key::OptimizationContainerKey,
    index::Union{Int, Nothing} = nothing,
)
    container = getfield(data, get_store_container_type(key))
    # Return a copy because callers may mutate it.
    if isnothing(index)
        return copy(container[key], copycols = true)
    else
        return copy(container[key], copycols = true)[index, :]
    end
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
