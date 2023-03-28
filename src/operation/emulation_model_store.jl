"""
Stores results data for one EmulationModel
"""
mutable struct EmulationModelStore <: AbstractModelStore
    data_container::DatasetContainer{DataFrameDataset}
    optimizer_stats::OrderedDict{Int, OptimizerStats}
end

get_data_field(store::EmulationModelStore, type::Symbol) =
    getfield(store.data_container, type)

function EmulationModelStore()
    return EmulationModelStore(
        DatasetContainer{DataFrameDataset}(),
        OrderedDict{Int, OptimizerStats}(),
    )
end

function Base.empty!(store::EmulationModelStore)
    stype = DatasetContainer
    for (name, _) in zip(fieldnames(stype), fieldtypes(stype))
        if name ∉ [:values, :timestamps]
            val = get_data_field(store, name)
            try
                empty!(val)
            catch
                @error "Base.empty! must be customized for type $stype or skipped"
                rethrow()
            end
        elseif name == :update_timestamp
            store.update_timestamp = UNSET_INI_TIME
        else
            setfield!(
                store.data_container,
                name,
                zero(fieldtype(store.data_container, name)),
            )
        end
    end
    empty!(store.optimizer_stats)
    return
end

function Base.isempty(store::EmulationModelStore)
    stype = DatasetContainer
    for (name, type) in zip(fieldnames(stype), fieldtypes(stype))
        if name ∉ [:values, :timestamps]
            val = get_data_field(store, name)
            try
                !isempty(val) && return false
            catch
                @error "Base.isempty must be customized for type $stype or skipped"
                rethrow()
            end
        elseif name == :update_timestamp
            store.update_timestamp != UNSET_INI_TIME && return false
        else
            val = get_data_fieldd(store, name)
            iszero(val) && return false
        end
    end
    return isempty(store.optimizer_stats)
end

function initialize_storage!(
    store::EmulationModelStore,
    container::OptimizationContainer,
    params::ModelStoreParams,
)
    num_of_executions = get_num_executions(params)
    for type in STORE_CONTAINERS
        field_containers = getfield(container, type)
        results_container = get_data_field(store, type)
        for (key, field_container) in field_containers
            @debug "Adding $(encode_key_as_string(key)) to EmulationModelStore" _group =
                LOG_GROUP_MODEL_STORE
            column_names = get_column_names(key, field_container)
            results_container[key] = DataFrameDataset(
                DataFrames.DataFrame(
                    OrderedDict(c => fill(NaN, num_of_executions) for c in column_names),
                ),
            )
        end
    end
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
    container = get_data_field(store, get_store_container_type(key))
    set_value!(container[key], df_row, index)
    set_last_recorded_row!(container[key], index)
    set_update_timestamp!(container[key], update_timestamp)
    return
end

function read_results(
    store::EmulationModelStore,
    key::OptimizationContainerKey;
    index::Union{Int, Nothing} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    container = get_data_field(store, get_store_container_type(key))
    df = container[key].values
    # Return a copy because callers may mutate it.
    if isnothing(index)
        @assert_op len === nothing
        return copy(df; copycols = true)
    elseif isnothing(len)
        return copy(df; copycols = true)[index:end, :]
    else
        return copy(df; copycols = true)[index:(index + len - 1), :]
    end
end

function get_dataset_size(store::EmulationModelStore, key::OptimizationContainerKey)
    container = get_data_field(store, get_store_container_type(key))
    return size(container[key].values)
end

function get_last_updated_timestamp(
    store::EmulationModelStore,
    key::OptimizationContainerKey,
)
    container = get_data_field(store, get_store_container_type(key))
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
    return get_last_recorded_row(x.data_container, key)
end
