
struct DecisionModelSimulationResults <: OperationModelSimulationResults
    variables::FieldResultsByTime
    duals::FieldResultsByTime
    parameters::FieldResultsByTime
    aux_variables::FieldResultsByTime
    expressions::FieldResultsByTime
    forecast_horizon::Int
    container_key_lookup::Dict{String, OptimizationContainerKey}
end

function SimulationProblemResults(
    ::Type{DecisionModel},
    store::SimulationStore,
    model_name::AbstractString,
    problem_params::ModelStoreParams,
    sim_params::SimulationStoreParams,
    path,
    container_key_lookup;
    kwargs...,
)
    name = Symbol(model_name)
    variables = list_decision_model_keys(store, name, STORE_CONTAINER_VARIABLES)
    parameters = list_decision_model_keys(store, name, STORE_CONTAINER_PARAMETERS)
    duals = list_decision_model_keys(store, name, STORE_CONTAINER_DUALS)
    aux_variables = list_decision_model_keys(store, name, STORE_CONTAINER_AUX_VARIABLES)
    expressions = list_decision_model_keys(store, name, STORE_CONTAINER_EXPRESSIONS)

    return SimulationProblemResults{DecisionModelSimulationResults}(
        store,
        model_name,
        problem_params,
        sim_params,
        path,
        DecisionModelSimulationResults(
            _fill_result_value_container(variables),
            _fill_result_value_container(duals),
            _fill_result_value_container(parameters),
            _fill_result_value_container(aux_variables),
            _fill_result_value_container(expressions),
            get_horizon(problem_params),
            container_key_lookup,
        );
        kwargs...,
    )
end

function Base.empty!(res::SimulationProblemResults{DecisionModelSimulationResults})
    foreach(empty!, _get_dicts(res))
    empty!(res.results_timestamps)
    return
end

Base.isempty(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    all(isempty, _get_dicts(res))

# This returns the number of timestamps stored in all containers.
Base.length(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    mapreduce(length, +, _get_dicts(res))

_get_dicts(res::SimulationProblemResults) =
    (y for x in _get_containers(res) for y in values(x))

function get_forecast_horizon(res::SimulationProblemResults{DecisionModelSimulationResults})
    return res.values.forecast_horizon
end

function _get_store_value(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    container_keys::Vector{<:OptimizationContainerKey},
    timestamps,
    ::Nothing,
)
    simulation_store_path = joinpath(get_execution_path(res), "data_store")
    return open_store(HdfSimulationStore, simulation_store_path, "r") do store
        _get_store_value(res, container_keys, timestamps, store)
    end
end

function _get_store_value(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    container_keys::Vector{<:OptimizationContainerKey},
    timestamps,
    store::SimulationStore,
)
    base_power = get_model_base_power(res)
    results =
        Dict{OptimizationContainerKey, SortedDict{Dates.DateTime, DataFrames.DataFrame}}()
    model_name = Symbol(get_model_name(res))
    resolution = get_resolution(res)
    horizon = get_forecast_horizon(res)
    for key in container_keys
        _results = SortedDict{Dates.DateTime, DataFrames.DataFrame}()
        for ts in timestamps
            out = read_result(DataFrames.DataFrame, store, model_name, key, ts)
            if convert_result_to_natural_units(key)
                out .*= base_power
            end
            time_col = range(ts, length=horizon, step=resolution)
            DataFrames.insertcols!(out, 1, :DateTime => time_col)
            _results[ts] = out
        end
        results[key] = _results
    end

    return results
end

function _process_timestamps(
    res::SimulationProblemResults,
    initial_time::Union{Nothing, Dates.DateTime},
    count::Union{Nothing, Int},
)
    if initial_time === nothing
        initial_time = first(get_timestamps(res))
    end

    if initial_time ∉ res.timestamps
        invalid_timestamps = [initial_time]
    else
        if count === nothing
            requested_range = [v for v in res.timestamps if v >= initial_time]
        else
            requested_range =
                collect(range(initial_time, length=count, step=get_interval(res)))
        end
        invalid_timestamps = [v for v in requested_range if v ∉ res.timestamps]
    end
    if !isempty(invalid_timestamps)
        @error "Timestamps $(invalid_timestamps) not stored" get_timestamps(res)
        throw(IS.InvalidValue("Timestamps not stored"))
    end
    return requested_range
end

function _read_variables(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    variable_keys,
    timestamps,
    store,
)
    isempty(variable_keys) && return FieldResultsByTime()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end
    _validate_keys(keys(get_variables(res)), variable_keys)
    same_timestamps = isempty(setdiff(res.results_timestamps, timestamps))
    keys_with_values = [k for (k, v) in get_variables(res) if !isempty(v)]
    same_keys = isempty([n for n in variable_keys if n ∉ keys_with_values])
    if same_timestamps && same_keys
        @debug "reading variables from SimulationsResults"
        vals = filter(p -> (p.first ∈ variable_keys), get_variables(res))
    else
        @debug "reading variables from data store"
        vals = _get_store_value(res, variable_keys, timestamps, store)
    end
    return vals
end

"""
Return the values for the requested variable. It keeps requests when performing multiple retrievals.

# Arguments

  - `args`: Can be a string returned from [`list_variable_names`](@ref) or args that can be
    splatted into a VariableKey.
  - `initial_time::Dates.DateTime` : initial of the requested results
  - `count::Int`: Number of results
  - `store::SimulationStore`: a store that has been opened for reading

# Examples

```julia
read_variable(results, ActivePowerVariable, ThermalStandard)
read_variable(results, "ActivePowerVariable__ThermalStandard")
```
"""
function read_variable(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    args...;
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
    store=nothing,
)
    key = _deserialize_key(VariableKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return _read_variables(res, [key], timestamps, store)[key]
end

function _read_duals(res::SimulationProblemResults, dual_keys, timestamps, store)
    isempty(dual_keys) && return FieldResultsByTime()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end
    _validate_keys(keys(get_duals(res)), dual_keys)
    same_timestamps = isempty(setdiff(res.results_timestamps, timestamps))
    keys_with_values = [k for (k, v) in get_duals(res) if !isempty(v)]
    same_keys = isempty([n for n in dual_keys if n ∉ keys_with_values])
    if same_timestamps && same_keys
        @debug "reading duals from SimulationsResults"
        vals = filter(p -> (p.first ∈ dual_keys), get_duals(res))
    else
        @debug "reading duals from data store"
        vals = _get_store_value(res, dual_keys, timestamps, store)
    end
    return vals
end

"""
Return the values for the requested dual. It keeps requests when performing multiple retrievals.

# Arguments

  - `args`: Can be a string returned from [`list_dual_names`](@ref) or args that can be
    splatted into a ConstraintKey.
  - `initial_time::Dates.DateTime` : initial of the requested results
  - `count::Int`: Number of results
  - `store::SimulationStore`: a store that has been opened for reading
"""
function read_dual(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    args...;
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
    store=nothing,
)
    key = _deserialize_key(ConstraintKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return _read_duals(res, [key], timestamps, store)[key]
end

function _read_parameters(res::SimulationProblemResults, parameter_keys, timestamps, store)
    isempty(parameter_keys) && return FieldResultsByTime()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end
    _validate_keys(keys(get_parameters(res)), parameter_keys)
    same_timestamps = isempty(setdiff(res.results_timestamps, timestamps))
    parameters_with_values = [k for (k, v) in get_parameters(res) if !isempty(v)]
    same_parameters = isempty([n for n in parameter_keys if n ∉ parameters_with_values])
    if same_timestamps && same_parameters
        @debug "reading parameters from SimulationsResults"
        vals = filter(p -> (p.first ∈ parameter_keys), get_parameters(res))
    else
        @debug "reading parameters from data store"
        vals = _get_store_value(res, parameter_keys, timestamps, store)
    end
    return vals
end

"""
Return the values for the requested parameter. It keeps requests when performing multiple retrievals.

# Arguments

  - `args`: Can be a string returned from [`list_parameter_names`](@ref) or args that can be
    splatted into a ParameterKey.
  - `initial_time::Dates.DateTime` : initial of the requested results
  - `count::Int`: Number of results
"""
function read_parameter(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    args...;
    time_series_name=nothing,
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
    store=nothing,
)
    key = _deserialize_key(ParameterKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return _read_parameters(res, [key], timestamps, store)[key]
end

function _read_aux_variables(
    res::SimulationProblemResults,
    aux_variable_keys,
    timestamps,
    store,
)
    isempty(aux_variable_keys) && return FieldResultsByTime()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end
    _validate_keys(keys(get_aux_variables(res)), aux_variable_keys)
    same_timestamps = isempty(setdiff(res.results_timestamps, timestamps))
    keys_with_values = [k for (k, v) in get_aux_variables(res) if !isempty(v)]
    same_keys = isempty([n for n in aux_variable_keys if n ∉ keys_with_values])
    if same_timestamps && same_keys
        @debug "reading aux variables from SimulationsResults"
        vals = filter(p -> (p.first ∈ aux_variable_keys), get_aux_variables(res))
    else
        @debug "reading aux variables from data store"
        vals = _get_store_value(res, aux_variable_keys, timestamps, store)
    end
    return vals
end

"""
Return the values for the requested auxillary variables. It keeps requests when performing multiple retrievals.

# Arguments

  - `args`: Can be a string returned from [`list_aux_variable_names`](@ref) or args that can be
    splatted into a AuxVarKey.
  - `initial_time::Dates.DateTime` : initial of the requested results
  - `count::Int`: Number of results
"""
function read_aux_variable(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    args...;
    time_series_name=nothing,
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
    store=nothing,
)
    key = _deserialize_key(AuxVarKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return _read_aux_variables(res, [key], timestamps, store)[key]
end

function _read_expressions(
    res::SimulationProblemResults,
    expression_keys,
    timestamps,
    store,
)
    isempty(expression_keys) && return FieldResultsByTime()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end
    _validate_keys(keys(get_expressions(res)), expression_keys)
    same_timestamps = isempty(setdiff(res.results_timestamps, timestamps))
    keys_with_values = [k for (k, v) in get_expressions(res) if !isempty(v)]
    same_keys = isempty([n for n in expression_keys if n ∉ keys_with_values])
    if same_timestamps && same_keys
        @debug "reading expressions from SimulationsResults"
        vals = filter(p -> (p.first ∈ expression_keys), get_expressions(res))
    else
        @debug "reading expressions from data store"
        vals = _get_store_value(res, expression_keys, timestamps, store)
    end
    return vals
end

"""
Return the values for the requested auxillary variables. It keeps requests when performing multiple retrievals.

# Arguments

  - `args`: Can be a string returned from [`list_expression_names`](@ref) or args that can be
    splatted into a ExpressionKey.
  - `initial_time::Dates.DateTime` : initial of the requested results
  - `count::Int`: Number of results
"""
function read_expression(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    args...;
    time_series_name=nothing,
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
    store=nothing,
)
    key = _deserialize_key(ExpressionKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return _read_expressions(res, [key], timestamps, store)[key]
end

function get_realized_timestamps(
    res::IS.Results;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    timestamps = get_timestamps(res)
    interval = timestamps.step
    resolution = get_resolution(res)
    horizon = get_forecast_horizon(res)
    start_time = isnothing(start_time) ? first(timestamps) : start_time
    end_time =
        isnothing(len) ? last(timestamps) + interval - resolution :
        start_time + (len - 1) * resolution

    requested_range = start_time:resolution:end_time
    available_range =
        first(timestamps):resolution:(last(timestamps) + (horizon - 1) * resolution)
    invalid_timestamps = setdiff(requested_range, available_range)

    if !isempty(invalid_timestamps)
        msg = "Requested time does not match available results"
        @error msg
        throw(IS.InvalidValue(msg))
    end

    return requested_range
end

function read_variables_with_keys(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    variables::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    meta = RealizedMeta(res, start_time=start_time, len=len)
    timestamps = _process_timestamps(res, meta.start_time, meta.len)
    result_values = _read_variables(res, variables, timestamps, nothing)
    return get_realization(result_values, meta)
end

function read_parameters_with_keys(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    parameters::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    meta = RealizedMeta(res, start_time=start_time, len=len)
    timestamps = _process_timestamps(res, meta.start_time, meta.len)
    result_values = _read_parameters(res, parameters, timestamps, nothing)
    return get_realization(result_values, meta)
end

function read_duals_with_keys(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    duals::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    meta = RealizedMeta(res, start_time=start_time, len=len)
    timestamps = _process_timestamps(res, meta.start_time, meta.len)
    result_values = _read_duals(res, duals, timestamps, nothing)
    return get_realization(result_values, meta)
end

function read_aux_variables_with_keys(
    res::SimulationProblemResults,
    aux_variables::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    meta = RealizedMeta(res, start_time=start_time, len=len)
    timestamps = _process_timestamps(res, meta.start_time, meta.len)
    result_values = _read_aux_variables(res, aux_variables, timestamps, nothing)
    return get_realization(result_values, meta)
end

function read_expressions_with_keys(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    expressions::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    meta = RealizedMeta(res, start_time=start_time, len=len)
    timestamps = _process_timestamps(res, meta.start_time, meta.len)
    result_values = _read_expressions(res, expressions, timestamps, nothing)
    return get_realization(result_values, meta)
end

"""
Load the simulation results into memory for repeated reads. Running this function twice
overwrites the previously loaded results. This is useful when loading results from remote
locations over network connections.

For each variable/parameter/dual, etc., each element must be the name encoded as a string,
like `"ActivePowerVariable__ThermalStandard"` or a Tuple with its constituent types, like
`(ActivePowerVariable, ThermalStandard)`.

# Arguments

  - `count::Int`: Number of windows to load.
  - `initial_time::Dates.DateTime` : Initial time of first window to load. Defaults to first.
  - `aux_variables::Vector{Union{String, Tuple}}`: Optional list of aux variables to load.
  - `duals::Vector{Union{String, Tuple}}`: Optional list of duals to load.
  - `expressions::Vector{Union{String, Tuple}}`: Optional list of expressions to load.
  - `parameters::Vector{Union{String, Tuple}}`: Optional list of parameters to load.
  - `variables::Vector{Union{String, Tuple}}`: Optional list of variables to load.
"""
function load_results!(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    count::Int;
    initial_time::Union{Dates.DateTime, Nothing}=nothing,
    variables=Vector{Tuple}(),
    duals=Vector{Tuple}(),
    parameters=Vector{Tuple}(),
    aux_variables=Vector{Tuple}(),
    expressions=Vector{Tuple}(),
)
    initial_time = initial_time === nothing ? first(get_timestamps(res)) : initial_time

    res.results_timestamps = _process_timestamps(res, initial_time, count)

    dual_keys = [_deserialize_key(ConstraintKey, res, x...) for x in duals]
    parameter_keys = [_deserialize_key(ParameterKey, res, x...) for x in parameters]
    variable_keys = [_deserialize_key(VariableKey, res, x...) for x in variables]
    aux_variable_keys = [_deserialize_key(AuxVarKey, res, x...) for x in aux_variables]
    expression_keys = [_deserialize_key(ExpressionKey, res, x...) for x in expressions]
    function merge_results(store)
        merge!(
            get_variables(res),
            _read_variables(res, variable_keys, res.results_timestamps, store),
        )
        merge!(get_duals(res), _read_duals(res, dual_keys, res.results_timestamps, store))
        merge!(
            get_parameters(res),
            _read_parameters(res, parameter_keys, res.results_timestamps, store),
        )
        merge!(
            get_aux_variables(res),
            _read_aux_variables(res, aux_variable_keys, res.results_timestamps, store),
        )
        merge!(
            get_expressions(res),
            _read_expressions(res, expression_keys, res.results_timestamps, store),
        )
    end

    if res.store isa InMemorySimulationStore
        merge_results(res.store)
    else
        simulation_store_path = joinpath(res.execution_path, "data_store")
        open_store(HdfSimulationStore, simulation_store_path, "r") do store
            merge_results(store)
        end
    end

    return nothing
end

function _read_optimizer_stats(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    store::SimulationStore,
)
    return read_optimizer_stats(store, Symbol(res.problem))
end
