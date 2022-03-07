const ResultsByTime = SortedDict{Dates.DateTime, DataFrames.DataFrame}
const FieldResultsByTime = Dict{OptimizationContainerKey, ResultsByTime}

"""
Holds the results of a simulation problem for plotting or exporting.
"""
mutable struct SimulationProblemResults <: IS.Results
    problem::String
    base_power::Float64
    execution_path::String
    results_output_folder::String
    timestamps::StepRange{Dates.DateTime, Dates.Millisecond}
    results_timestamps::Vector{Dates.DateTime}
    system::Union{Nothing, PSY.System}
    system_uuid::Base.UUID
    resolution::Dates.TimePeriod
    forecast_horizon::Int
    variable_values::FieldResultsByTime
    dual_values::FieldResultsByTime
    parameter_values::FieldResultsByTime
    aux_variable_values::FieldResultsByTime
    expression_values::FieldResultsByTime
    optimization_container_metadata::OptimizationContainerMetadata
    store::Union{Nothing, SimulationStore}
end

function SimulationProblemResults(
    store::SimulationStore,
    model_name::AbstractString,
    problem_params::ModelStoreParams,
    sim_params::SimulationStoreParams,
    path;
    results_output_path=nothing,
    system=nothing,
)
    if results_output_path === nothing
        results_output_path = joinpath(path, "results")
    end

    time_steps = range(
        sim_params.initial_time,
        length=problem_params.num_executions * sim_params.num_steps,
        step=problem_params.interval,
    )
    name = Symbol(model_name)
    variables = list_fields(store, name, STORE_CONTAINER_VARIABLES)
    parameters = list_fields(store, name, STORE_CONTAINER_PARAMETERS)
    duals = list_fields(store, name, STORE_CONTAINER_DUALS)
    aux_variables = list_fields(store, name, STORE_CONTAINER_AUX_VARIABLES)
    expressions = list_fields(store, name, STORE_CONTAINER_EXPRESSIONS)

    return SimulationProblemResults(
        model_name,
        problem_params.base_power,
        path,
        results_output_path,
        time_steps,
        Vector{Dates.DateTime}(),
        system,
        problem_params.system_uuid,
        get_resolution(problem_params),
        get_horizon(problem_params),
        _fill_result_value_container(variables),
        _fill_result_value_container(duals),
        _fill_result_value_container(parameters),
        _fill_result_value_container(aux_variables),
        _fill_result_value_container(expressions),
        deserialize_metadata(
            OptimizationContainerMetadata,
            joinpath(path, "problems"),
            name,
        ),
        store isa HdfSimulationStore ? nothing : store,
    )
end

function Base.empty!(res::SimulationProblemResults)
    foreach(empty!, _get_dicts(res))
    empty!(res.results_timestamps)
    return
end

Base.isempty(res::SimulationProblemResults) = all(isempty, _get_dicts(res))

# This returns the number of timestamps stored in all containers.
Base.length(res::SimulationProblemResults) = mapreduce(length, +, _get_dicts(res))

get_model_name(res::SimulationProblemResults) = res.problem
get_system(res::SimulationProblemResults) = res.system
get_resolution(res::SimulationProblemResults) = res.resolution
get_forecast_horizon(res::SimulationProblemResults) = res.forecast_horizon
get_execution_path(res::SimulationProblemResults) = res.execution_path
get_model_base_power(res::SimulationProblemResults) = res.base_power
IS.get_timestamp(result::SimulationProblemResults) = result.results_timestamps
get_interval(res::SimulationProblemResults) = res.timestamps.step
IS.get_base_power(result::SimulationProblemResults) = result.base_power

"""
Return an array of variable names (strings) that are available for reads.
"""
list_variable_names(res::SimulationProblemResults) =
    encode_keys_as_strings(keys(res.variable_values))

"""
Return an array of dual names (strings) that are available for reads.
"""
list_dual_names(res::SimulationProblemResults) =
    encode_keys_as_strings(keys(res.dual_values))

"""
Return an array of parmater names (strings) that are available for reads.
"""
list_parameter_names(res::SimulationProblemResults) =
    encode_keys_as_strings(keys(res.parameter_values))

"""
Return an array of auxillary variable names (strings) that are available for reads.
"""
list_aux_variable_names(res::SimulationProblemResults) =
    encode_keys_as_strings(keys(res.aux_variable_values))

"""
Return an array of expression names (strings) that are available for reads.
"""
list_expression_names(res::SimulationProblemResults) =
    encode_keys_as_strings(keys(res.expression_values))

"""
Return an array of VariableKeys that are available for reads.
"""
list_variable_keys(res::SimulationProblemResults) = collect(keys(res.variable_values))

"""
Return an array of ConstraintKeys that are available for reading duals.
"""
list_dual_keys(res::SimulationProblemResults) = collect(keys(res.dual_values))

"""
Return an array of ParameterKeys that are available for reads.
"""
list_parameter_keys(res::SimulationProblemResults) = collect(keys(res.parameter_values))

"""
Return an array of AuxVarKeys that are available for reads.
"""
list_aux_variable_keys(res::SimulationProblemResults) =
    collect(keys(res.aux_variable_values))

"""
Return an array of ExpressionKeys that are available for reads.
"""
list_expression_keys(res::SimulationProblemResults) = collect(keys(res.expression_values))

"""
Return a reference to all variable values that have been loaded into memory.
"""
get_variable_values(result::SimulationProblemResults) = result.variable_values

"""
Return a reference to all dual values that have been loaded into memory.
"""
get_dual_values(result::SimulationProblemResults) = result.dual_values

"""
Return a reference to all parameter values that have been loaded into memory.
"""
get_parameter_values(result::SimulationProblemResults) = result.parameter_values

"""
Return a reference to all auxillary variable values that have been loaded into memory.
"""
get_aux_variable_values(result::SimulationProblemResults) = result.aux_variable_values

"""
Return a reference to all expression values that have been loaded into memory.
"""
get_expression_values(result::SimulationProblemResults) = result.expression_values

"""
Return a reference to a StepRange of available timestamps.
"""
get_timestamps(result::SimulationProblemResults) = result.timestamps

"""
Return the system used for the problem. If the system hasn't already been deserialized or
set with [`set_system!`](@ref) then deserialize and store it.
"""
function get_system!(results::SimulationProblemResults)
    file = joinpath(
        results.execution_path,
        "problems",
        results.problem,
        make_system_filename(results.system_uuid),
    )
    results.system = PSY.System(file, time_series_read_only=true)
    return results.system
end

"""
Set the system in the results instance.

Throws InvalidValue if the system UUID is incorrect.

# Arguments

  - `results::SimulationProblemResults`: Results object
  - `system::AbstractString`: Path to the system json file

# Examples

```julia
julia > set_system!(res, "my_path/system_data.json")
```
"""
function set_system!(results::SimulationProblemResults, system::AbstractString)
    set_system!(results, System(system))
end

function set_system!(results::SimulationProblemResults, system::PSY.System)
    sys_uuid = IS.get_uuid(system)
    if sys_uuid != results.system_uuid
        throw(
            IS.InvalidValue(
                "System mismatch. $sys_uuid does not match the stored value of $(results.system_uuid)",
            ),
        )
    end

    results.system = system
    return
end

function _deserialize_key(
    ::Type{<:OptimizationContainerKey},
    results::SimulationProblemResults,
    name::AbstractString,
)
    return deserialize_key(results.optimization_container_metadata, name)
end

function _deserialize_key(
    ::Type{T},
    results::SimulationProblemResults,
    args...,
) where {T <: OptimizationContainerKey}
    return make_key(T, args...)
end

_get_containers(x::SimulationProblemResults) =
    (x.variable_values, x.parameter_values, x.dual_values)
_get_dicts(res::SimulationProblemResults) =
    (y for x in _get_containers(res) for y in values(x))

function _get_store_value(
    res::SimulationProblemResults,
    container_keys::Vector{<:OptimizationContainerKey},
    timestamps,
    ::Nothing,
)
    simulation_store_path = joinpath(get_execution_path(res), "data_store")
    problem_path = joinpath(get_execution_path(res), "problems")
    return open_store(
        HdfSimulationStore,
        simulation_store_path,
        "r",
        problem_path=problem_path,
    ) do store
        _get_store_value(res, container_keys, timestamps, store)
    end
end

function _get_store_value(
    res::SimulationProblemResults,
    container_keys::Vector{<:OptimizationContainerKey},
    timestamps,
    store::SimulationStore,
)
    results =
        Dict{OptimizationContainerKey, SortedDict{Dates.DateTime, DataFrames.DataFrame}}()
    model_name = Symbol(get_model_name(res))
    resolution = get_resolution(res)
    horizon = get_forecast_horizon(res)
    for key in container_keys
        _results = SortedDict{Dates.DateTime, DataFrames.DataFrame}()
        for ts in timestamps
            out = read_result(DataFrames.DataFrame, store, model_name, key, ts)
            time_col = range(ts, length=horizon, step=resolution)
            DataFrames.insertcols!(out, 1, :DateTime => time_col)
            _results[ts] = out
        end
        results[key] = _results
    end

    return results
end

function _validate_keys(existing_keys, container_keys)
    existing = Set(existing_keys)
    for key in container_keys
        if key ∉ existing
            @error "$key is not stored", existing_keys
            throw(IS.InvalidValue("$key is not stored"))
        end
    end
    return
end

function _process_timestamps(
    res::SimulationProblemResults,
    initial_time::Union{Nothing, Dates.DateTime},
    count::Union{Int, Nothing},
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

function _read_variables(res::SimulationProblemResults, variable_keys, timestamps, store)
    isempty(variable_keys) && return FieldResultsByTime()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end
    _validate_keys(keys(res.variable_values), variable_keys)
    same_timestamps = isempty(setdiff(res.results_timestamps, timestamps))
    keys_with_values = [k for (k, v) in res.variable_values if !isempty(v)]
    same_keys = isempty([n for n in variable_keys if n ∉ keys_with_values])
    if same_timestamps && same_keys
        @debug "reading variables from SimulationsResults"
        vals = filter(p -> (p.first ∈ variable_keys), res.variable_values)
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
    res::SimulationProblemResults,
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
    _validate_keys(keys(res.dual_values), dual_keys)
    same_timestamps = isempty(setdiff(res.results_timestamps, timestamps))
    keys_with_values = [k for (k, v) in res.dual_values if !isempty(v)]
    same_keys = isempty([n for n in dual_keys if n ∉ keys_with_values])
    if same_timestamps && same_keys
        @debug "reading duals from SimulationsResults"
        vals = filter(p -> (p.first ∈ dual_keys), res.dual_values)
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
    res::SimulationProblemResults,
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
    _validate_keys(keys(res.parameter_values), parameter_keys)
    same_timestamps = isempty(setdiff(res.results_timestamps, timestamps))
    parameters_with_values = [k for (k, v) in res.parameter_values if !isempty(v)]
    same_parameters = isempty([n for n in parameter_keys if n ∉ parameters_with_values])
    if same_timestamps && same_parameters
        @debug "reading parameters from SimulationsResults"
        vals = filter(p -> (p.first ∈ parameter_keys), res.parameter_values)
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
    res::SimulationProblemResults,
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
    _validate_keys(keys(res.aux_variable_values), aux_variable_keys)
    same_timestamps = isempty(setdiff(res.results_timestamps, timestamps))
    keys_with_values = [k for (k, v) in res.aux_variable_values if !isempty(v)]
    same_keys = isempty([n for n in aux_variable_keys if n ∉ keys_with_values])
    if same_timestamps && same_keys
        @debug "reading aux variables from SimulationsResults"
        vals = filter(p -> (p.first ∈ aux_variable_keys), res.aux_variable_values)
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
    res::SimulationProblemResults,
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
    _validate_keys(keys(res.expression_values), expression_keys)
    same_timestamps = isempty(setdiff(res.results_timestamps, timestamps))
    keys_with_values = [k for (k, v) in res.expression_values if !isempty(v)]
    same_keys = isempty([n for n in expression_keys if n ∉ keys_with_values])
    if same_timestamps && same_keys
        @debug "reading expressions from SimulationsResults"
        vals = filter(p -> (p.first ∈ expression_keys), res.expression_values)
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
    res::SimulationProblemResults,
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

"""
Return the optimizer stats for the problem as a DataFrame.

# Accepted keywords

  - `store::SimulationStore`: a store that has been opened for reading
"""
function read_optimizer_stats(res::SimulationProblemResults; store=nothing)
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end
    return _read_optimizer_stats(res, store)
end

function _read_optimizer_stats(res::SimulationProblemResults, ::Nothing)
    problem_path = joinpath(get_execution_path(res), "problems")
    open_store(
        HdfSimulationStore,
        joinpath(get_execution_path(res), "data_store"),
        "r",
        problem_path=problem_path,
    ) do store
        _read_optimizer_stats(res, store)
    end
end

function _read_optimizer_stats(res::SimulationProblemResults, store::SimulationStore)
    return read_optimizer_stats(store, Symbol(res.problem))
end

function get_realized_timestamps(
    res::IS.Results;
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    timestamps = get_timestamps(res)
    interval = timestamps.step
    resolution = get_resolution(res)
    horizon = get_forecast_horizon(res)
    initial_time = isnothing(initial_time) ? first(timestamps) : initial_time
    end_time =
        isnothing(len) ? last(timestamps) + interval - resolution :
        initial_time + (len - 1) * resolution

    requested_range = initial_time:resolution:end_time
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

struct RealizedMeta
    initial_time::Dates.DateTime
    resolution::Dates.TimePeriod
    count::Int
    start_offset::Int
    end_offset::Int
    interval_len::Int
    realized_timestamps::AbstractVector{Dates.DateTime}
end

function RealizedMeta(
    res::SimulationProblemResults;
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
)
    existing_timestamps = get_timestamps(res)
    interval = existing_timestamps.step
    resolution = get_resolution(res)
    interval_len = Int(interval / resolution)
    realized_timestamps = get_realized_timestamps(res, initial_time=initial_time, len=count)

    result_initial_time = existing_timestamps[findlast(
        x -> x .<= first(realized_timestamps),
        existing_timestamps,
    )]
    result_end_time = existing_timestamps[findlast(
        x -> x .<= last(realized_timestamps),
        existing_timestamps,
    )]

    count = length(result_initial_time:interval:result_end_time)

    start_offset = length(result_initial_time:resolution:first(realized_timestamps))
    end_offset = length(
        (last(realized_timestamps) + resolution):resolution:(result_end_time + interval - resolution),
    )

    return RealizedMeta(
        result_initial_time,
        resolution,
        count,
        start_offset,
        end_offset,
        interval_len,
        realized_timestamps,
    )
end

function get_realization(
    result_values::Dict{
        OptimizationContainerKey,
        SortedDict{Dates.DateTime, DataFrames.DataFrame},
    },
    meta::RealizedMeta,
)
    realized_values = Dict{OptimizationContainerKey, DataFrames.DataFrame}()
    for (key, result_value) in result_values
        results_concat = Dict{Symbol, Vector{Float64}}()
        for (step, (t, df)) in enumerate(result_value)
            first_id = step > 1 ? 1 : meta.start_offset
            last_id =
                step == meta.count ? meta.interval_len - meta.end_offset : meta.interval_len
            result_length = length(first_id:last_id)
            for colname in propertynames(df)
                colname == :DateTime && continue
                col = df[!, colname][first_id:last_id]
                if !haskey(results_concat, colname)
                    results_concat[colname] = col
                else
                    results_concat[colname] = vcat(results_concat[colname], col)
                end
            end
        end
        realized_values[key] = DataFrames.DataFrame(results_concat, copycols=false)
        DataFrames.insertcols!(
            realized_values[key],
            1,
            :DateTime => meta.realized_timestamps,
        )
    end
    return realized_values
end

"""
Return the final values for the requested variables for each time step for a problem.
Accepts a vector of tuples for the return of the values. If the time stamps and variables types are
loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `variables::Vector{Tuple{Type{<:VariableType}, Type{<:PSY.Component}}` : Tuple with variable type and device type for the desired results
  - `initial_time::Dates.DateTime` : initial time of the requested results
  - `count::Int`: length of results
"""
function read_realized_variables(res::SimulationProblemResults; kwargs...)
    return read_realized_variables(res, collect(keys(res.variable_values)); kwargs...)
end

function read_realized_variables(res::SimulationProblemResults, variables; kwargs...)
    return read_realized_variables(res, [VariableKey(x...) for x in variables]; kwargs...)
end

function read_realized_variables(
    res::SimulationProblemResults,
    variables::Vector{<:AbstractString};
    kwargs...,
)
    return read_realized_variables(
        res,
        [_deserialize_key(VariableKey, res, x) for x in variables];
        kwargs...,
    )
end

function read_realized_variables(
    res::SimulationProblemResults,
    variables::Vector{<:OptimizationContainerKey};
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
)
    result_values =
        read_variables_with_keys(res, variables; initial_time=initial_time, count=count)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

function read_variables_with_keys(
    res::SimulationProblemResults,
    variables::Vector{<:OptimizationContainerKey};
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
)
    meta = RealizedMeta(res, initial_time=initial_time, count=count)
    timestamps = _process_timestamps(res, meta.initial_time, meta.count)
    result_values = _read_variables(res, variables, timestamps, nothing)
    return get_realization(result_values, meta)
end

"""
Return the final values for the requested parameters for each time step for a problem.
If the time stamps and parameters are loaded using the [load_results!](@ref) function
it will read from memory.

# Arguments

  - `parameters::Vector{Tuple{Type{<:ParameterType}, Type{<:PSY.Component}}` : Tuple with parameter type and device type for the desired results
  - `initial_time::Dates.DateTime` : initial time of the requested results
  - `count::Int`: length of results
"""
function read_realized_parameters(res::SimulationProblemResults; kwargs...)
    return read_realized_parameters(res, collect(keys(res.parameter_values)); kwargs...)
end

function read_realized_parameters(res::SimulationProblemResults, parameters; kwargs...)
    return read_realized_parameters(
        res,
        [ParameterKey(x...) for x in parameters];
        kwargs...,
    )
end

function read_realized_parameters(
    res::SimulationProblemResults,
    parameters::Vector{<:AbstractString};
    kwargs...,
)
    return read_realized_parameters(
        res,
        [_deserialize_key(ParameterKey, res, x) for x in parameters];
        kwargs...,
    )
end

function read_realized_parameters(
    res::SimulationProblemResults,
    parameters::Vector{<:OptimizationContainerKey};
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
)
    result_values =
        read_parameters_with_keys(res, parameters; initial_time=initial_time, count=count)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

function read_parameters_with_keys(
    res::SimulationProblemResults,
    parameters::Vector{<:OptimizationContainerKey};
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
)
    meta = RealizedMeta(res, initial_time=initial_time, count=count)
    timestamps = _process_timestamps(res, meta.initial_time, meta.count)
    result_values = _read_parameters(res, parameters, timestamps, nothing)
    return get_realization(result_values, meta)
end

"""
Return the final values for the requested dual keys for each time step for a problem.
Accepts a vector of constraints and component types for the return of the values. If the
time stamps and keys are loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `duals::::Vector{Tuple{Type{<:ConstraintType}, Type{<:PSY.Component}}` : Tuple with constraint type and device type for the desired results
  - `initial_time::Dates.DateTime` : initial time of the requested results
  - `count::Int`: length of results
"""
function read_realized_duals(res::SimulationProblemResults; kwargs...)
    return read_realized_duals(res, collect(keys(res.dual_values)); kwargs...)
end

function read_realized_duals(res::SimulationProblemResults, duals; kwargs...)
    return read_realized_duals(res, [ConstraintKey(x...) for x in duals]; kwargs...)
end

function read_realized_duals(
    res::SimulationProblemResults,
    duals::Vector{<:AbstractString};
    kwargs...,
)
    return read_realized_duals(
        res,
        [_deserialize_key(ConstraintKey, res, x) for x in duals];
        kwargs...,
    )
end

function read_realized_duals(
    res::SimulationProblemResults,
    duals::Vector{<:OptimizationContainerKey};
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
)
    result_values = read_duals_with_keys(res, duals; initial_time=initial_time, count=count)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

function read_duals_with_keys(
    res::SimulationProblemResults,
    duals::Vector{<:OptimizationContainerKey};
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
)
    meta = RealizedMeta(res, initial_time=initial_time, count=count)
    timestamps = _process_timestamps(res, meta.initial_time, meta.count)
    result_values = _read_duals(res, duals, timestamps, nothing)
    return get_realization(result_values, meta)
end

"""
Return the final values for the requested auxiliary variable keys for each time step for a problem.
Accepts a vector of tuples for the return of the values. If the
time stamps and keys are loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `aux_variables::::Vector{Tuple{Type{<:AuxVariableType}, Type{<:PSY.Component}}` : Tuple with auxiliary variable type and device type for the desired results
  - `initial_time::Dates.DateTime` : initial time of the requested results
  - `count::Int`: length of results
"""
function read_realized_aux_variables(res::SimulationProblemResults; kwargs...)
    return read_realized_aux_variables(
        res,
        collect(keys(res.aux_variable_values));
        kwargs...,
    )
end

function read_realized_aux_variables(
    res::SimulationProblemResults,
    aux_variables;
    kwargs...,
)
    return read_realized_aux_variables(
        res,
        [AuxVarKey(x...) for x in aux_variables];
        kwargs...,
    )
end

function read_realized_aux_variables(
    res::SimulationProblemResults,
    aux_variables::Vector{<:AbstractString};
    kwargs...,
)
    return read_realized_aux_variables(
        res,
        [_deserialize_key(AuxVarKey, res, x) for x in aux_variables];
        kwargs...,
    )
end

function read_realized_aux_variables(
    res::SimulationProblemResults,
    aux_variables::Vector{<:OptimizationContainerKey};
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
)
    result_values = read_aux_variables_with_keys(
        res,
        aux_variables;
        initial_time=initial_time,
        count=count,
    )
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

function read_aux_variables_with_keys(
    res::SimulationProblemResults,
    aux_variables::Vector{<:OptimizationContainerKey};
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
)
    meta = RealizedMeta(res, initial_time=initial_time, count=count)
    timestamps = _process_timestamps(res, meta.initial_time, meta.count)
    result_values = _read_aux_variables(res, aux_variables, timestamps, nothing)
    return get_realization(result_values, meta)
end

"""
Return the final values for the requested expression keys for each time step for a problem.
Accepts a vector of tuples for the return of the values. If the
time stamps and keys are loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `expressions::::Vector{Tuple{Type{<:ExpressionType}, U <: Union{PSY.Component, PSY.System}}` : Tuple with expression type and device type or system for the desired results
  - `initial_time::Dates.DateTime` : initial time of the requested results
  - `count::Int`: length of results
"""
function read_realized_expressions(res::SimulationProblemResults; kwargs...)
    return read_realized_expressions(res, collect(keys(res.expression_values)); kwargs...)
end

function read_realized_expressions(res::SimulationProblemResults, expressions; kwargs...)
    return read_realized_expressions(
        res,
        [ExpressionKey(x...) for x in expressions];
        kwargs...,
    )
end

function read_realized_expressions(
    res::SimulationProblemResults,
    expressions::Vector{<:AbstractString};
    kwargs...,
)
    return read_realized_expressions(
        res,
        [_deserialize_key(ExpressionKey, res, x) for x in expressions];
        kwargs...,
    )
end

function read_realized_expressions(
    res::SimulationProblemResults,
    expressions::Vector{<:OptimizationContainerKey};
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
)
    result_values =
        read_expressions_with_keys(res, expressions; initial_time=initial_time, count=count)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

function read_expressions_with_keys(
    res::SimulationProblemResults,
    expressions::Vector{<:OptimizationContainerKey};
    initial_time::Union{Nothing, Dates.DateTime}=nothing,
    count::Union{Int, Nothing}=nothing,
)
    meta = RealizedMeta(res, initial_time=initial_time, count=count)
    timestamps = _process_timestamps(res, meta.initial_time, meta.count)
    result_values = _read_expressions(res, expressions, timestamps, nothing)
    return get_realization(result_values, meta)
end

"""
    Loads the simulation results into memory for repeated reads. Running this function twice
    overwrites the previously loaded results. This is useful when loading results from remote
    locations over network connections

    # Required Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
    # Accepted Key Words
    - `variables::Vector{Tuple{Type{<:VariableType}, Type{<:PSY.Component}}` : Tuple with variable type and device type for the desired results
    - `duals::Vector{Tuple{Type{<:ConstraintType}, Type{<:PSY.Component}}` : Tuple with constraint type and device type for the desired results
    - `parameters::Vector{Tuple{Type{<:ParameterType}, Type{<:PSY.Component}}` : Tuple with parameter type and device type for the desired results
    - `aux_variables::Vector{Tuple{Type{<:AuxVariableType}, Type{<:PSY.Component}}` : Tuple with auxilary variable type and device type for the desired results
    - `expressions::Vector{Tuple{Type{<:ExpressionType}, U <: Union{PSY.Component, PSY.System}}` : Tuple with expression type and device type or system for the desired results
"""
function load_results!(
    res::SimulationProblemResults,
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
            res.variable_values,
            _read_variables(res, variable_keys, res.results_timestamps, store),
        )
        merge!(res.dual_values, _read_duals(res, dual_keys, res.results_timestamps, store))
        merge!(
            res.parameter_values,
            _read_parameters(res, parameter_keys, res.results_timestamps, store),
        )
        merge!(
            res.aux_variable_values,
            _read_aux_variables(res, aux_variable_keys, res.results_timestamps, store),
        )
        merge!(
            res.expression_values,
            _read_expressions(res, expression_keys, res.results_timestamps, store),
        )
    end

    if res.store isa InMemorySimulationStore
        merge_results(res.store)
    else
        simulation_store_path = joinpath(res.execution_path, "data_store")
        problem_path = joinpath(get_execution_path(res), "problems")
        open_store(
            HdfSimulationStore,
            simulation_store_path,
            "r",
            problem_path=problem_path,
        ) do store
            merge_results(store)
        end
    end

    return nothing
end

"""
Save the realized results to CSV files for all variables, paramaters, duals, auxiliary variables,
expressions, and optimizer statistics.

# Arguments

  - `res::Union{ProblemResults, SimulationProblmeResults`: Results
  - `save_path::AbstractString` : path to save results (defaults to simulation path)
"""
function export_realized_results(res::ProblemResults)
    save_path = mkpath(joinpath(res.output_dir, "export"))
    return export_realized_results(res, save_path)
end

function export_realized_results(res::SimulationProblemResults)
    save_path = mkpath(joinpath(res.results_output_folder, "export"))
    return export_realized_results(res, save_path)
end

function export_realized_results(
    res::Union{ProblemResults, SimulationProblemResults},
    save_path::AbstractString,
)
    if !isdir(save_path)
        throw(IS.ConflictingInputsError("Specified path is not valid."))
    end
    write_data(read_variables_with_keys(res, list_variable_keys(res)), save_path)
    !isempty(list_dual_keys(res)) &&
        write_data(read_duals_with_keys(res, list_dual_keys(res)), save_path; name="dual")
    !isempty(list_parameter_keys(res)) && write_data(
        read_parameters_with_keys(res, list_parameter_keys(res)),
        save_path;
        name="parameter",
    )
    !isempty(list_aux_variable_keys(res)) && write_data(
        read_aux_variables_with_keys(res, list_aux_variable_keys(res)),
        save_path;
        name="aux_variable",
    )
    !isempty(list_expression_keys(res)) && write_data(
        read_expressions_with_keys(res, list_expression_keys(res)),
        save_path;
        name="expression",
    )
    export_optimizer_stats(res, save_path)
    files = readdir(save_path)
    compute_file_hash(save_path, files)
    @info("Files written to $save_path folder.")
    return save_path
end

"""
Save the optimizer statistics to CSV or JSON

# Arguments

  - `res::Union{ProblemResults, SimulationProblmeResults`: Results
  - `directory::AbstractString` : target directory
  - `format = "CSV"` : can be "csv" or "json
"""
function export_optimizer_stats(
    res::Union{ProblemResults, SimulationProblemResults},
    directory::AbstractString;
    format="csv",
)
    data = read_optimizer_stats(res)
    if uppercase(format) == "CSV"
        CSV.write(joinpath(directory, "optimizer_stats.csv"), data)
    elseif uppercase(format) == "JSON"
        JSON.write(joinpath(directory, "optimizer_stats.json"), JSON.json(to_dict(data)))
    else
        throw(error("writing optimizer stats only supports csv or json formats"))
    end
end
