"""
Stores results data for one DecisionModel
"""
mutable struct DecisionModelOptimizerResults <: AbstractModelOptimizerResults
    duals::Dict{ConstraintKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    parameters::Dict{ParameterKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    variables::Dict{VariableKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    aux_variables::Dict{AuxVarKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    expressions::Dict{ExpressionKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    optimizer_stats::OrderedDict{Dates.DateTime, OptimizerStats}
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
        OrderedDict{Dates.DateTime, OptimizerStats}(),
    )
end

function write_result!(
    data::DecisionModelOptimizerResults,
    field::Symbol,
    key::OptimizationContainerKey,
    timestamp::Dates.DateTime,
    array,
    columns,
)
    container = getfield(data, field)
    df = axis_array_to_dataframe(array, columns)
    container[key][timestamp] = df
    return
end

function read_results(
    data::DecisionModelOptimizerResults,
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
    results::DecisionModelOptimizerResults,
    stats::OptimizerStats,
    timestamp::Dates.DateTime,
)
    @assert !(timestamp in keys(results.optimizer_stats))
    results.optimizer_stats[timestamp] = stats
end

function read_optimizer_stats(store::DecisionModelOptimizerResults)
    stats = [to_namedtuple(x) for x in values(store.optimizer_stats)]
    df = DataFrames.DataFrame(stats)
    DataFrames.insertcols!(df, 1, :DateTime => keys(store.optimizer_stats))
    return df
end
