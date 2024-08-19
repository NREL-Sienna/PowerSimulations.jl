struct DecisionModelSimulationResults <: OperationModelSimulationResults
    variables::ResultsByKeyAndTime
    duals::ResultsByKeyAndTime
    parameters::ResultsByKeyAndTime
    aux_variables::ResultsByKeyAndTime
    expressions::ResultsByKeyAndTime
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
    return SimulationProblemResults{DecisionModelSimulationResults}(
        store,
        model_name,
        problem_params,
        sim_params,
        path,
        DecisionModelSimulationResults(
            ResultsByKeyAndTime(
                list_decision_model_keys(store, name, STORE_CONTAINER_VARIABLES),
            ),
            ResultsByKeyAndTime(
                list_decision_model_keys(store, name, STORE_CONTAINER_DUALS),
            ),
            ResultsByKeyAndTime(
                list_decision_model_keys(store, name, STORE_CONTAINER_PARAMETERS),
            ),
            ResultsByKeyAndTime(
                list_decision_model_keys(store, name, STORE_CONTAINER_AUX_VARIABLES),
            ),
            ResultsByKeyAndTime(
                list_decision_model_keys(store, name, STORE_CONTAINER_EXPRESSIONS),
            ),
            get_horizon_count(problem_params),
            container_key_lookup,
        );
        kwargs...,
    )
end

function _list_containers(res::SimulationProblemResults{DecisionModelSimulationResults})
    return (getfield(res.values, x).cached_results for x in get_container_fields(res))
end

function Base.empty!(res::SimulationProblemResults{DecisionModelSimulationResults})
    foreach(empty!, _list_containers(res))
    empty!(get_results_timestamps(res))
end

function Base.isempty(res::SimulationProblemResults{DecisionModelSimulationResults})
    all(isempty, _list_containers(res))
end

# This returns the number of timestamps stored in all containers.
function Base.length(res::SimulationProblemResults{DecisionModelSimulationResults})
    return mapreduce(length, +, (y for x in _list_containers(res) for y in values(x)))
end

list_aux_variable_keys(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    res.values.aux_variables.result_keys[:]
list_dual_keys(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    res.values.duals.result_keys[:]
list_expression_keys(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    res.values.expressions.result_keys[:]
list_parameter_keys(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    res.values.parameters.result_keys[:]
list_variable_keys(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    res.values.variables.result_keys[:]

get_cached_aux_variables(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    res.values.aux_variables.cached_results
get_cached_duals(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    res.values.duals.cached_results
get_cached_expressions(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    res.values.expressions.cached_results
get_cached_parameters(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    res.values.parameters.cached_results
get_cached_variables(res::SimulationProblemResults{DecisionModelSimulationResults}) =
    res.values.variables.cached_results

get_cached_results(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    ::AuxVarKey,
) = get_cached_aux_variables(res)
get_cached_results(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    ::ConstraintKey,
) = get_cached_duals(res)
get_cached_results(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    ::ExpressionKey,
) = get_cached_expressions(res)
get_cached_results(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    ::ParameterKey,
) = get_cached_parameters(res)
get_cached_results(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    ::VariableKey,
) = get_cached_variables(res)

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
    sim_results::SimulationProblemResults{DecisionModelSimulationResults},
    container_keys::Vector{<:OptimizationContainerKey},
    timestamps::Vector{Dates.DateTime},
    store::SimulationStore,
)
    results_by_key = Dict{OptimizationContainerKey, ResultsByTime}()
    model_name = Symbol(get_model_name(sim_results))
    for ckey in container_keys
        n_dims = get_number_of_dimensions(store, DecisionModelIndexType, model_name, ckey)
        container_type = DenseAxisArray{Float64, n_dims + 1}
        results_by_key[ckey] = _get_store_value(container_type,
            sim_results,
            ckey,
            timestamps, store)
    end
    return results_by_key
end

function _get_store_value(
    ::Type{T},
    sim_results::SimulationProblemResults{DecisionModelSimulationResults},
    key::OptimizationContainerKey,
    timestamps::Vector{Dates.DateTime},
    store::SimulationStore,
) where {T <: DenseAxisArray{Float64, 2}}
    resolution = get_resolution(sim_results)
    horizon = get_forecast_horizon(sim_results)
    base_power = get_model_base_power(sim_results)
    model_name = Symbol(get_model_name(sim_results))
    results_by_time = ResultsByTime(
        key,
        SortedDict{Dates.DateTime, T}(),
        resolution,
        get_column_names(store, DecisionModelIndexType, model_name, key),
    )
    array_size::Union{Nothing, Tuple{Int, Int}} = nothing
    for ts in timestamps
        array = read_result(DenseAxisArray, store, model_name, key, ts)
        if isnothing(array_size)
            array_size = size(array)
        elseif size(array) != array_size
            error(
                "Arrays for $(encode_key_as_string(key)) at different timestamps have different sizes",
            )
        end
        if convert_result_to_natural_units(key)
            array.data .*= base_power
        end
        if array_size[2] != horizon
            @warn "$(encode_key_as_string(key)) has a different horizon than the " *
                  "problem specification. Can't assign timestamps to the resulting DataFrame."
            results_by_time.resolution = Dates.Period(Dates.Millisecond(0))
        end
        results_by_time[ts] = array
    end

    return results_by_time
end

function _get_store_value(
    ::Type{T},
    sim_results::SimulationProblemResults{DecisionModelSimulationResults},
    key::OptimizationContainerKey,
    timestamps::Vector{Dates.DateTime},
    store::SimulationStore,
) where {T <: DenseAxisArray{Float64, 3}}
    resolution = get_resolution(sim_results)
    horizon = get_forecast_horizon(sim_results)
    base_power = get_model_base_power(sim_results)
    model_name = Symbol(get_model_name(sim_results))
    results_by_time = ResultsByTime(
        key,
        SortedDict{Dates.DateTime, T}(),
        resolution,
        get_column_names(store, DecisionModelIndexType, model_name, key),
    )
    array_size::Union{Nothing, Tuple{Int, Int, Int}} = nothing
    for ts in timestamps
        array = read_result(DenseAxisArray, store, model_name, key, ts)
        if isnothing(array_size)
            array_size = size(array)
        elseif size(array) != array_size
            error(
                "Arrays for $(encode_key_as_string(key)) at different timestamps have different sizes",
            )
        end
        if convert_result_to_natural_units(key)
            array.data .*= base_power
        end
        if array_size[3] != horizon
            @warn "$(encode_key_as_string(key)) has a different horizon than the " *
                  "problem specification. Can't assign timestamps to the resulting DataFrame."
            results_by_time.resolution = Dates.Period(Dates.Millisecond(0))
        end
        results_by_time[ts] = array
    end

    return results_by_time
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
                collect(range(initial_time; length = count, step = get_interval(res)))
        end
        invalid_timestamps = [v for v in requested_range if v ∉ res.timestamps]
    end
    if !isempty(invalid_timestamps)
        @error "Timestamps $(invalid_timestamps) not stored" get_timestamps(res)
        throw(IS.InvalidValue("Timestamps not stored"))
    end
    return requested_range
end

function _read_results(
    ::Type{Matrix{Float64}},
    res::SimulationProblemResults{DecisionModelSimulationResults},
    result_keys,
    timestamps::Vector{Dates.DateTime},
    store::Union{Nothing, <:SimulationStore};
    cols::Union{Colon, Vector{String}} = (:),
)
    vals = _read_results(res, result_keys, timestamps, store)
    converted_vals = Dict{OptimizationContainerKey, ResultsByTime{Matrix{Float64}}}()
    for (result_key, result_data) in vals
        inner_converted = SortedDict(
            (date_key, Matrix{Float64}(permutedims(inner_data[cols, :].data)))
            for (date_key, inner_data) in result_data.data)
        converted_vals[result_key] = ResultsByTime{Matrix{Float64}, 1}(
            result_data.key,
            inner_converted,
            result_data.resolution,
            (cols isa Vector) ? (cols,) : result_data.column_names)
    end
    return converted_vals
end

function _read_results(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    result_keys,
    timestamps::Vector{Dates.DateTime},
    store::Union{Nothing, <:SimulationStore},
)
    isempty(result_keys) &&
        return Dict{OptimizationContainerKey, ResultsByTime{DenseAxisArray{Float64, 2}}}()

    _store = try_resolve_store(store, res.store)
    existing_keys = list_result_keys(res, first(result_keys))
    IS.Optimization._validate_keys(existing_keys, result_keys)
    cached_results = get_cached_results(res, eltype(result_keys))
    if _are_results_cached(res, result_keys, timestamps, keys(cached_results))
        @debug "reading results from SimulationsResults cache"  # NOTE tests match on this
        vals = Dict(k => cached_results[k] for k in result_keys)
        # Cached data may contain more timestamps than we need, remove these if so
        (timestamps == get_results_timestamps(res)) && return vals
        filtered_vals = Dict{keytype(vals), valtype(vals)}()
        for (result_key, result_data) in vals
            inner_converted = filter((((k, v),) -> k in timestamps), result_data.data)
            filtered_vals[result_key] = ResultsByTime{valtype(inner_converted), 1}(
                result_data.key,
                inner_converted,
                result_data.resolution,
                result_data.column_names)
        end
        return filtered_vals
    else
        @debug "reading results from data store"  # NOTE tests match on this
        vals = _get_store_value(res, result_keys, timestamps, _store)
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
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    key = _deserialize_key(VariableKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return make_dataframes(_read_results(res, [key], timestamps, store)[key])
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
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    key = _deserialize_key(ConstraintKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return make_dataframes(
        _read_results(res, [key], timestamps, store)[key],
    )
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
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    key = _deserialize_key(ParameterKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return make_dataframes(
        _read_results(res, [key], timestamps, store)[key],
    )
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
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    key = _deserialize_key(AuxVarKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return make_dataframes(
        _read_results(res, [key], timestamps, store)[key],
    )
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
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    key = _deserialize_key(ExpressionKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return make_dataframes(
        _read_results(res, [key], timestamps, store)[key],
    )
end

function get_realized_timestamps(
    res::IS.Results;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    timestamps = get_timestamps(res)
    interval = timestamps.step
    resolution = get_resolution(res)
    horizon = get_forecast_horizon(res)
    start_time = isnothing(start_time) ? first(timestamps) : start_time
    end_time =
        if isnothing(len)
            last(timestamps) + interval - resolution
        else
            start_time + (len - 1) * resolution
        end

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

"""
High-level function to read a DataFrame of results.

# Arguments

  - `res`: the results to read.
  - `result_keys::Vector{<:OptimizationContainerKey}`: the keys to read. Output will be a
    `Dict{OptimizationContainerKey, DataFrame}` with these as the keys
  - `start_time::Union{Nothing, Dates.DateTime} = nothing`: the time at which the resulting
    time series should begin; `nothing` indicates the first time in the results
  - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series;
    `nothing` indicates up to the end of the results
  - `cols::Union{Colon, Vector{String}} = (:)`: which columns to fetch; defaults to `:`,
    i.e., all the columns
"""
function read_results_with_keys(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    result_keys::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
    cols::Union{Colon, Vector{String}} = (:),
)
    meta = RealizedMeta(res; start_time = start_time, len = len)
    timestamps = _process_timestamps(res, meta.start_time, meta.len)
    result_values =
        _read_results(Matrix{Float64}, res, result_keys, timestamps, nothing; cols = cols)
    return get_realization(result_values, meta)
end

function _are_results_cached(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    output_keys::Vector{<:OptimizationContainerKey},
    timestamps::Vector{Dates.DateTime},
    cached_keys,
)
    return isempty(setdiff(timestamps, get_results_timestamps(res))) &&
           isempty(setdiff(output_keys, cached_keys))
end

"""
Load the simulation results into memory for repeated reads. This is useful when loading
results from remote locations over network connections, when reading the same data very many
times, etc. Multiple calls augment the cache according to these rules, where "variable"
means "variable, expression, etc.":
  - Requests for an already cached variable at a lesser `count` than already cached do *not*
    decrease the `count` of the cached variable
  - Requests for an already cached variable at a greater `count` than already cached *do*
    increase the `count` of the cached variable
  - Requests for new variables are fulfilled without evicting existing variables

Note that `count` is global across all variables, so increasing the `count` re-reads already
cached variables. For each variable, each element must be the name encoded as a string, like
`"ActivePowerVariable__ThermalStandard"` or a Tuple with its constituent types, like
`(ActivePowerVariable, ThermalStandard)`. To clear the cache, use [`Base.empty!`](@ref).

# Arguments

  - `count::Int`: Number of windows to load.
  - `initial_time::Dates.DateTime` : Initial time of first window to load. Defaults to
    first.
  - `aux_variables::Vector{Union{String, Tuple}}`: Optional list of aux variables to load.
  - `duals::Vector{Union{String, Tuple}}`: Optional list of duals to load.
  - `expressions::Vector{Union{String, Tuple}}`: Optional list of expressions to load.
  - `parameters::Vector{Union{String, Tuple}}`: Optional list of parameters to load.
  - `variables::Vector{Union{String, Tuple}}`: Optional list of variables to load.
"""
function load_results!(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    count::Int;
    initial_time::Union{Dates.DateTime, Nothing} = nothing,
    variables = Vector{Tuple}(),
    duals = Vector{Tuple}(),
    parameters = Vector{Tuple}(),
    aux_variables = Vector{Tuple}(),
    expressions = Vector{Tuple}(),
    store::Union{Nothing, <:SimulationStore} = nothing,
)
    initial_time = initial_time === nothing ? first(get_timestamps(res)) : initial_time
    count = max(count, length(get_results_timestamps(res)))
    new_timestamps = _process_timestamps(res, initial_time, count)

    for (key_type, new_items) in [
        (ConstraintKey, duals),
        (ParameterKey, parameters),
        (VariableKey, variables),
        (AuxVarKey, aux_variables),
        (ExpressionKey, expressions),
    ]
        new_keys = key_type[_deserialize_key(key_type, res, x...) for x in new_items]
        existing_results = get_cached_results(res, key_type)
        total_keys = union(collect(keys(existing_results)), new_keys)
        # _read_results checks the cache to eliminate unnecessary re-reads
        merge!(existing_results, _read_results(res, total_keys, new_timestamps, store))
    end
    set_results_timestamps!(res, new_timestamps)

    return nothing
end

function _read_optimizer_stats(
    res::SimulationProblemResults{DecisionModelSimulationResults},
    store::SimulationStore,
)
    return read_optimizer_stats(store, Symbol(res.problem))
end
