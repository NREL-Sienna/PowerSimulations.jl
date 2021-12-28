"""
Stores results data for one EmulationModel
"""
mutable struct EmulationModelStore <: AbstractModelStore
    last_recorded_row::Int
    duals::Dict{ConstraintKey, DataFrames.DataFrame}
    parameters::Dict{ParameterKey, DataFrames.DataFrame}
    variables::Dict{VariableKey, DataFrames.DataFrame}
    aux_variables::Dict{AuxVarKey, DataFrames.DataFrame}
    expressions::Dict{ExpressionKey, DataFrames.DataFrame}
    optimizer_stats::OrderedDict{Int, OptimizerStats}
end

function EmulationModelStore()
    return EmulationModelStore(
        0,
        Dict{ConstraintKey, DataFrames.DataFrame}(),
        Dict{ParameterKey, DataFrames.DataFrame}(),
        Dict{VariableKey, DataFrames.DataFrame}(),
        Dict{AuxVarKey, DataFrames.DataFrame}(),
        Dict{ExpressionKey, DataFrames.DataFrame}(),
        OrderedDict{Int, OptimizerStats}(),
    )
end

function Base.empty!(store::EmulationModelStore)
    stype = typeof(store)
    for (name, type) in zip(fieldnames(stype), fieldtypes(stype))
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
            container_axes = axes(field_container)
            @debug "Adding $(encode_key_as_string(key)) to EmulationModelStore" _group =
                LOG_GROUP_MODEL_STORE
            if length(container_axes) == 2
                if type == STORE_CONTAINER_PARAMETERS
                    column_names = string.(get_parameter_array(field_container).axes[1])
                else
                    column_names = string.(axes(field_container)[1])
                end
                results_container[key] = DataFrames.DataFrame(
                    OrderedDict(c => fill(NaN, num_of_executions) for c in column_names),
                )
            elseif length(container_axes) == 1
                @assert_op container_axes[1] == get_time_steps(container)
                results_container[key] =
                    DataFrames.DataFrame("System" => fill(NaN, num_of_executions))
            else
                error("Container structure for $(encode_key_as_string(key)) not supported")
            end
        end
    end
end

function write_result!(
    data::EmulationModelStore,
    field::Symbol,
    key::OptimizationContainerKey,
    execution::Int,
    array,
)
    container = getfield(data, field)
    df = axis_array_to_dataframe(array, key)
    container[key][execution, :] = df[1, :]
    return
end

function read_results(
    data::EmulationModelStore,
    container_type::Symbol,
    key::OptimizationContainerKey,
    index = nothing,
)
    container = getfield(data, container_type)
    # Return a copy because callers may mutate it.
    return copy(container[key], copycols = true)
end

function write_optimizer_stats!(
    store::EmulationModelStore,
    stats::OptimizerStats,
    execution::Int,
)
    @assert !(execution in keys(store.optimizer_stats))
    store.optimizer_stats[execution] = stats
end

function read_optimizer_stats(store::EmulationModelStore)
    return DataFrames.DataFrame([to_namedtuple(x) for x in values(store.optimizer_stats)])
end

get_last_recorded_row(x::EmulationModelStore) = x.last_recorded_row

function set_last_recorded_row!(store::EmulationModelStore, execution)
    @debug "set_last_recorded_row!" _group = LOG_GROUP_MODEL_STORE execution
    store.last_recorded_row = execution
    return
end
