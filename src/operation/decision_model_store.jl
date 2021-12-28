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
            container_axes = axes(field_container)
            @debug "Adding $(encode_key_as_string(key)) to DecisionModelStore" _group =
                LOG_GROUP_MODEL_STORE
            results_container[key] = OrderedDict{Dates.DateTime, DataFrames.DataFrame}()
            for timestamp in
                range(initial_time, step = model_interval, length = num_of_executions)
                if length(container_axes) == 2
                    if type == STORE_CONTAINER_PARAMETERS
                        column_names = string.(get_parameter_array(field_container).axes[1])
                    else
                        column_names = string.(axes(field_container)[1])
                    end

                    results_container[key][timestamp] = DataFrames.DataFrame(
                        OrderedDict(c => fill(NaN, time_steps_count) for c in column_names),
                    )
                elseif length(container_axes) == 1
                    results_container[key][timestamp] = DataFrames.DataFrame(
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

function write_result!(
    data::DecisionModelStore,
    field::Symbol,
    key::OptimizationContainerKey,
    timestamp::Dates.DateTime,
    array,
)
    container = getfield(data, field)
    df = axis_array_to_dataframe(array, key)
    container[key][timestamp] = df
    return
end

function read_results(
    data::DecisionModelStore,
    container_type::Symbol,
    key::OptimizationContainerKey,
    timestamp = nothing,
)
    container = getfield(data, container_type)
    data = container[key]
    if isnothing(timestamp)
        @assert length(data) == 1
        timestamp = first(keys(data))
    end

    # Return a copy because callers may mutate it.
    return copy(data[timestamp], copycols = true)
end

function write_optimizer_stats!(
    store::DecisionModelStore,
    stats::OptimizerStats,
    timestamp::Dates.DateTime,
)
    @assert !(timestamp in keys(store.optimizer_stats))
    store.optimizer_stats[timestamp] = stats
end

function read_optimizer_stats(store::DecisionModelStore)
    stats = [to_namedtuple(x) for x in values(store.optimizer_stats)]
    df = DataFrames.DataFrame(stats)
    DataFrames.insertcols!(df, 1, :DateTime => keys(store.optimizer_stats))
    return df
end
