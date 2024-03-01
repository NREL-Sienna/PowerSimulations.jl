"""
Stores results data for one DecisionModel
"""
mutable struct DecisionModelStore <: IS.AbstractModelStore
    # All DenseAxisArrays have axes (column names, row indexes)
    duals::Dict{IS.ConstraintKey, OrderedDict{Dates.DateTime, DenseAxisArray{Float64, 2}}}
    parameters::Dict{
        IS.ParameterKey,
        OrderedDict{Dates.DateTime, DenseAxisArray{Float64, 2}},
    }
    variables::Dict{IS.VariableKey, OrderedDict{Dates.DateTime, DenseAxisArray{Float64, 2}}}
    aux_variables::Dict{AuxVarKey, OrderedDict{Dates.DateTime, DenseAxisArray{Float64, 2}}}
    expressions::Dict{
        IS.ExpressionKey,
        OrderedDict{Dates.DateTime, DenseAxisArray{Float64, 2}},
    }
    optimizer_stats::OrderedDict{Dates.DateTime, IS.OptimizerStats}
end

function DecisionModelStore()
    return DecisionModelStore(
        Dict{IS.ConstraintKey, OrderedDict{Dates.DateTime, DenseAxisArray{Float64, 2}}}(),
        Dict{IS.ParameterKey, OrderedDict{Dates.DateTime, DenseAxisArray{Float64, 2}}}(),
        Dict{IS.VariableKey, OrderedDict{Dates.DateTime, DenseAxisArray{Float64, 2}}}(),
        Dict{AuxVarKey, OrderedDict{Dates.DateTime, DenseAxisArray{Float64, 2}}}(),
        Dict{IS.ExpressionKey, OrderedDict{Dates.DateTime, DenseAxisArray{Float64, 2}}}(),
        OrderedDict{Dates.DateTime, IS.OptimizerStats}(),
    )
end

function initialize_storage!(
    store::DecisionModelStore,
    container::IS.IS.AbstractOptimizationContainer,
    params::ModelStoreParams,
)
    num_of_executions = get_num_executions(params)
    if length(get_time_steps(container)) < 1
        error("The time step count in the optimization container is not defined")
    end
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
            column_names = get_column_names(key, field_container)
            data = OrderedDict{Dates.DateTime, DenseAxisArray{Float64, 2}}()
            for timestamp in
                range(initial_time; step = model_interval, length = num_of_executions)
                data[timestamp] = fill!(
                    DenseAxisArray{Float64}(undef, column_names..., 1:time_steps_count),
                    NaN,
                )
            end
            results_container[key] = data
        end
    end
    return
end

function write_result!(
    store::DecisionModelStore,
    name::Symbol,
    key::IS.OptimizationContainerKey,
    index::DecisionModelIndexType,
    update_timestamp::Dates.DateTime,
    array::DenseAxisArray{<:Any, 2},
)
    columns = axes(array)[1]
    if eltype(columns) !== String
        # TODO: This happens because buses are stored by indexes instead of name.
        columns = string.(columns)
    end
    container = getfield(store, get_store_container_type(key))
    container[key][index] = DenseAxisArray(array.data, columns, 1:size(array)[2])
    return
end

function write_result!(
    store::DecisionModelStore,
    name::Symbol,
    key::IS.OptimizationContainerKey,
    index::DecisionModelIndexType,
    update_timestamp::Dates.DateTime,
    array::DenseAxisArray{<:Any, 1},
)
    columns = axes(array)[1]
    if eltype(columns) !== String
        # TODO: This happens because buses are stored by indexes instead of name.
        columns = string.(columns)
    end
    container = getfield(store, get_store_container_type(key))
    container[key][index] = DenseAxisArray(to_matrix(array), ["1"], columns)
    return
end

function read_results(
    store::DecisionModelStore,
    key::IS.OptimizationContainerKey;
    index::Union{DecisionModelIndexType, Nothing} = nothing,
)
    container = getfield(store, get_store_container_type(key))
    data = container[key]
    if isnothing(index)
        @assert length(data) == 1
        index = first(keys(data))
    end

    # Return a copy because callers may mutate it.
    return deepcopy(data[index])
end

function write_optimizer_stats!(
    store::DecisionModelStore,
    stats::IS.OptimizerStats,
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

function get_column_names(store::DecisionModelStore, key::IS.OptimizationContainerKey)
    container = getfield(store, get_store_container_type(key))
    return get_column_names(key, first(values(container[key])))
end
