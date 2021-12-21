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
    optimizer_stats::OrderedDict{Int, OptimizerStats}
end

function EmulationModelOptimizerResults()
    return EmulationModelOptimizerResults(
        0,
        Dict{ConstraintKey, DataFrames.DataFrame}(),
        Dict{ParameterKey, DataFrames.DataFrame}(),
        Dict{VariableKey, DataFrames.DataFrame}(),
        Dict{AuxVarKey, DataFrames.DataFrame}(),
        Dict{ExpressionKey, DataFrames.DataFrame}(),
        OrderedDict{Int, OptimizerStats}(),
    )
end

function write_result!(
    data::EmulationModelOptimizerResults,
    field::Symbol,
    key::OptimizationContainerKey,
    execution::Int,
    array,
    columns,
)
    container = getfield(data, field)
    df = axis_array_to_dataframe(array, columns)
    container[key][execution, :] = df[1, :]
    return
end

function read_results(
    data::EmulationModelOptimizerResults,
    container_type::Symbol,
    key::OptimizationContainerKey,
    index = nothing,
)
    container = getfield(data, container_type)
    # Return a copy because callers may mutate it.
    return copy(container[key], copycols = true)
end

function write_optimizer_stats!(
    results::EmulationModelOptimizerResults,
    stats::OptimizerStats,
    execution::Int,
)
    # TODO DT: This trips in one test. Should we enforce this rule?
    #@assert !(execution in keys(results.optimizer_stats))
    results.optimizer_stats[execution] = stats
end

function read_optimizer_stats(results::EmulationModelOptimizerResults)
    return DataFrames.DataFrame([to_namedtuple(x) for x in values(results.optimizer_stats)])
end

get_last_recorded_row(x::EmulationModelOptimizerResults) = x.last_recorded_row

function set_last_recorded_row!(results::EmulationModelOptimizerResults, execution)
    @debug "set_last_recorded_row!" _group = LOG_GROUP_IN_MEMORY_MODEL_STORE execution
    results.last_recorded_row = execution
    return
end
