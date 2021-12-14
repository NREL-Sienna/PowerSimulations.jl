# TODO:
# - Allow passing the system path if the simulation wasn't serialized
# - Handle PER-UNIT conversion of variables according to type
# - Enconde Variable/Parameter/Dual from other inputs to avoid passing Symbol

const ResultsByTime = SortedDict{Dates.DateTime, DataFrames.DataFrame}
const FieldResultsByTime = Dict{OptimizationContainerKey, ResultsByTime}

"""
Holds the results of a simulation problem for plotting or exporting.
"""
mutable struct SimulationProblemResults
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
    end_of_interval_step::Int
    variable_values::FieldResultsByTime
    dual_values::FieldResultsByTime
    parameter_values::FieldResultsByTime
    optimization_container_metadata::OptimizationContainerMetadata
    store::Union{Nothing, SimulationStore}
end

function SimulationProblemResults(
    store::SimulationStore,
    model_name::AbstractString,
    problem_params::ModelStoreParams,
    sim_params::SimulationStoreParams,
    path;
    results_output_path = nothing,
    system = nothing,
)
    if results_output_path === nothing
        results_output_path = joinpath(path, "results")
    end

    time_steps = range(
        sim_params.initial_time,
        length = problem_params.num_executions * sim_params.num_steps,
        step = problem_params.interval,
    )
    name = Symbol(model_name)
    variables = list_fields(store, name, STORE_CONTAINER_VARIABLES)
    parameters = list_fields(store, name, STORE_CONTAINER_PARAMETERS)
    duals = list_fields(store, name, STORE_CONTAINER_DUALS)

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
        get_end_of_interval_step(problem_params),
        _fill_result_value_container(variables),
        _fill_result_value_container(duals),
        _fill_result_value_container(parameters),
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
get_end_of_interval_step(res::SimulationProblemResults) = res.end_of_interval_step
get_execution_path(res::SimulationProblemResults) = res.execution_path
get_model_base_power(res::SimulationProblemResults) = res.base_power
IS.get_timestamp(result::SimulationProblemResults) = result.results_timestamps
get_interval(res::SimulationProblemResults) = res.timestamps.step
IS.get_base_power(result::SimulationProblemResults) = result.base_power

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
Return an array of variable names (strings) that are available for reads.
"""
list_variable_names(res::SimulationProblemResults) =
    encode_keys_as_strings(keys(res.variable_values))

"""
Return a reference to all dual values that have been loaded into memory.
"""
get_dual_values(result::SimulationProblemResults) = result.dual_values

"""
Return a reference to all parameter values that have been loaded into memory.
"""
get_parameter_values(result::SimulationProblemResults) = result.parameter_values

"""
Return a reference to a StepRange of available timestamps.
"""
get_timestamps(result::SimulationProblemResults) = result.timestamps

"""
Return a reference to all variable values that have been loaded into memory.
"""
get_variable_values(result::SimulationProblemResults) = result.variable_values

"""
Return the system used for the problem. If the system hasn't already been deserialized or
set with [`set_system!`](@ref) then deserialize and store it.
"""
function get_system!(results::SimulationProblemResults)
    file = joinpath(
        results.execution_path,
        "problems",
        make_system_filename(results.system_uuid),
    )
    results.system = PSY.System(file, time_series_read_only = true)
    return results.system
end

"""
Set the system in the results instance.

Throws InvalidValue if the system UUID is incorrect.
"""
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
    field::Symbol,
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
        problem_path = problem_path,
    ) do store
        _get_store_value(res, field, container_keys, timestamps, store)
    end
end

function _get_store_value(
    res::SimulationProblemResults,
    field::Symbol,
    names::Vector{<:OptimizationContainerKey},
    timestamps,
    store::SimulationStore,
)
    results =
        Dict{OptimizationContainerKey, SortedDict{Dates.DateTime, DataFrames.DataFrame}}()
    model_name = Symbol(get_model_name(res))
    problem_interval = get_interval(res)
    resolution = get_resolution(res)
    horizon = get_forecast_horizon(res)
    for name in names
        _results = SortedDict{Dates.DateTime, DataFrames.DataFrame}()
        for ts in timestamps
            out = read_result(DataFrames.DataFrame, store, model_name, field, name, ts)
            time_col = range(ts, length = horizon, step = resolution)
            DataFrames.insertcols!(out, 1, :DateTime => time_col)
            _results[ts] = out
        end
        results[name] = _results
    end

    return results
end

function _validate_keys(existing_keys, container_keys::Vector{<:OptimizationContainerKey})
    existing = Set(existing_keys)
    for key in container_keys
        if key ∉ existing
            @error "$key is not stored", sort(existing_keys)
            throw(IS.InvalidValue("$key is not stored"))
        end
    end
    nothing
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
                collect(range(initial_time, length = count, step = get_interval(res)))
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
    res::SimulationProblemResults,
    variable_keys::Vector{<:VariableKey},
    timestamps,
    store,
)
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
        @info "reading variables from SimulationsResults"
        vals = filter(p -> (p.first ∈ variable_keys), res.variable_values)
    else
        @info "reading variables from data store"
        vals = _get_store_value(
            res,
            STORE_CONTAINER_VARIABLES,
            variable_keys,
            timestamps,
            store,
        )
    end
    return vals
end

"""
Return the values for the requested variables in DataFrames in a two-level Dict keyed by
variable names and then timestamps.

If the timestamps and variables were loaded with [load_results!](@ref) or previously
returned by this function it will return from memory. Otherwise, it will read from the file.

# Arguments
- `variables::Union{Nothing, Vector{Union{String, Tuple}}}`: If nothing, return all
   variables. If strings then it must be values returned from [`list_variable_names`](@ref).
   If tuples then each tuple's contents must be able to be splatted into a VariableKey.
- `initial_time::Dates.DateTime`: initial of the requested results
- `count::Int`: Number of results
- `store::SimulationStore`: a store that has been opened for reading

# Examples
```julia
julia> read_variables(res, [(ActivePowerVariable, ThermalStandard)])
julia> read_variables(res, ["ActivePowerVariable__ThermalStandard")])
```
"""
# TODO: the read.*internal functions can likely be deleted.
function read_variables_internal(
    res::SimulationProblemResults;
    variables::Union{Nothing, Vector{Union{String, Tuple}}} = nothing,
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    variable_keys = _get_keys(VariableKey, res, variables)
    timestamps = _process_timestamps(res, initial_time, count)
    var_values = _read_variables(res, variable_keys, timestamps, store)
    return var_values
end

function _read_duals(
    res::SimulationProblemResults,
    dual_keys::Vector{<:ConstraintKey},
    timestamps,
    store,
)
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
        vals = _get_store_value(res, STORE_CONTAINER_DUALS, dual_keys, timestamps, store)
    end
    return vals
end

"""
Return the values for the requested duals in DataFrames in a two-level Dict keyed by
dual names and then timestamps.

If the timestamps and duals were loaded with [load_results!](@ref) or previously
returned by this function it will return from memory. Otherwise, it will read from the file.

# Arguments
- `duals::Union{Nothing, Vector{Union{String, Tuple}}}`: If nothing, return all
   duals. If strings then it must be values returned from [`list_dual_names`](@ref).
   If tuples then each tuple's contents must be able to be splatted into a ConstraintKey.
- `initial_time::Dates.DateTime` : initial of the requested results
- `count::Int`: Number of results
- `store::SimulationStore`: a store that has been opened for reading

# Examples
```julia
julia> read_duals(res, [(CopperPlateBalanceConstraint, PSY.System)])
julia> read_duals(res, ["CopperPlateBalanceConstraint_System"])
```
"""
function read_duals_internal(
    res::SimulationProblemResults;
    duals::Union{Nothing, Vector{Union{String, Tuple}}} = nothing,
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    dual_keys = _get_keys(ConstraintKey, res, duals)
    timestamps = _process_timestamps(res, initial_time, count)
    var_values = _read_duals(res, dual_keys, timestamps, store)
    return var_values
end

function _read_parameters(
    res::SimulationProblemResults,
    parameter_keys::Vector{<:ParameterKey},
    timestamps,
    store,
)
    isempty(parameter_keys) && return FieldResultsByTime()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end
    _validate_keys(res.parameter_values, parameter_keys)
    same_timestamps = isempty(setdiff(res.results_timestamps, timestamps))
    parameters_with_values = [k for (k, v) in res.parameter_values if !isempty(v)]
    same_parameters = isempty([n for n in parameter_keys if n ∉ parameters_with_values])
    if same_timestamps && same_parameters
        @info "reading parameters from SimulationsResults"
        vals = filter(p -> (p.first ∈ parameter_keys), res.parameter_values)
    else
        @info "reading parameters from data store"
        vals = _get_store_value(
            res,
            STORE_CONTAINER_PARAMETERS,
            parameter_keys,
            timestamps,
            store,
        )
    end
    return vals
end

"""
Return the values for the requested parameters in DataFrames in a two-level Dict keyed by
parameter names and then timestamps.

If the timestamps and parameters were loaded with [load_results!](@ref) or previously
returned by this function it will return from memory. Otherwise, it will read from the file.

# Arguments
- `parameters::Union{Nothing, Vector{Union{String, Tuple}}}`: If nothing, return all
   variables. If strings then it must be values returned from [`list_parameter_names`](@ref).
   If tuples then each tuple's contents must be able to be splatted into a ParameterKey.
- `initial_time::Dates.DateTime` : initial time of the requested results
- `count::Int`: Number of results
- `store::SimulationStore`: a store that has been opened for reading

# Examples
```julia
julia> read_parameters(res, [(ActivePowerTimeSeriesParameter, ThermalStandard)])
julia> read_parameters(res, ["ActivePowerTimeSeriesParameter_ThermalStandard"])
```
"""
function read_parameters_internal(
    res::SimulationProblemResults;
    parameters::Union{Nothing, Vector{Union{String, Tuple}}} = nothing,
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    parameter_keys = _get_keys(ParameterKey, res, parameters)
    timestamps = _process_timestamps(res, initial_time, count)
    values = _read_parameters(res, parameter_keys, timestamps, store)
    return values
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
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    key = _deserialize_key(VariableKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return _read_variables(res, [key], timestamps, store)
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
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    key = _deserialize_key(ConstraintKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return _read_duals(res, [key], timestamps, store)
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
    time_series_name = nothing,
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    # TODO: parameters are not handled correctly
    #parameter_key = ParameterKey(param_type(time_series_name), device_type)
    key = _deserialize_key(ParameterKey, res, args...)
    timestamps = _process_timestamps(res, initial_time, count)
    return _read_parameters(res; parameters = [key], kwargs...)[key]
end

"""
Return the optimizer stats for the problem as a DataFrame.

# Accepted keywords
- `store::SimulationStore`: a store that has been opened for reading
"""
function read_optimizer_stats(res::SimulationProblemResults; store = nothing)
    return _read_optimizer_stats(res, store)
end

function _read_optimizer_stats(res::SimulationProblemResults, ::Nothing)
    open_store(
        HdfSimulationStore,
        joinpath(get_execution_path(res), "data_store"),
        "r",
    ) do store
        _read_optimizer_stats(res, store)
    end
end

function _read_optimizer_stats(res::SimulationProblemResults, store::SimulationStore)
    return read_problem_optimizer_stats(store, Symbol(res.problem))
end

#struct RealizedMeta
#    initial_time::Dates.DateTime
#    resolution::Dates.TimePeriod
#    count::Int
#    start_offset::Int
#    end_offset::Int
#    interval_len::Int
#    end_of_interval_step::Int
#end
#
#function RealizedMeta(
#    res::SimulationProblemResults;
#    initial_time::Union{Nothing, Dates.DateTime} = nothing,
#    len::Union{Int, Nothing} = nothing,
#)
#    timestamps = get_timestamps(res)
#    interval = timestamps.step
#    resolution = get_resolution(res)
#    interval_len = Int(interval / resolution)
#    end_of_interval_step = get_end_of_interval_step(res)
#    realized_timestamps =
#        get_realized_timestamps(res, initial_time = initial_time, len = len)
#
#    result_initial_time = timestamps[findlast(
#        x -> x .<= first(realized_timestamps),
#        timestamps,
#    )]
#    result_end_time = timestamps[findlast(
#        x -> x .<= last(realized_timestamps),
#        timestamps,
#    )]
#
#    count = length(result_initial_time:interval:result_end_time)
#
#    start_offset = length(result_initial_time:resolution:first(realized_timestamps))
#    end_offset = length(
#        (last(realized_timestamps) + resolution):resolution:(result_end_time + interval - resolution),
#    )
#
#    return RealizedMeta(
#        result_initial_time,
#        resolution,
#        count,
#        start_offset,
#        end_offset,
#        interval_len,
#    )
#end
#
#function get_realized_timestamps(
#    res::SimulationProblemResults;
#    initial_time::Union{Nothing, Dates.DateTime} = nothing,
#    len::Union{Int, Nothing} = nothing,
#)
#    timestamps = get_timestamps(res)
#    interval = timestamps.step
#    resolution = get_resolution(res)
#    horizon = get_forecast_horizon(res)
#    initial_time = isnothing(initial_time) ? first(timestamps) : initial_time
#    end_time =
#        isnothing(len) ? last(timestamps) + interval - resolution :
#        initial_time + (len - 1) * resolution
#
#    requested_range = initial_time:resolution:end_time
#    available_range =
#        first(timestamps):resolution:(last(
#            timestamps,
#        ) + (horizon - 1) * resolution)
#    invalid_timestamps = setdiff(requested_range, available_range)
#
#    if !isempty(invalid_timestamps)
#        msg = "Requested time does not match available results"
#        @error msg
#        throw(IS.InvalidValue(msg))
#    end
#
#    return requested_range
#end
#
#function get_realization(
#    result_values::Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}},
#    meta::RealizedMeta,
#    timestamps,
#)
#    realized_values = Dict{Symbol, DataFrames.DataFrame}()
#    for (key, result_value) in result_values
#        results_concat = Dict{Symbol, Vector{Float64}}()
#        for (step, (t, df)) in enumerate(result_value)
#            first_id = step > 1 ? 1 : meta.start_offset
#            last_id =
#                step == meta.count ? meta.interval_len - meta.end_offset : meta.interval_len
#            result_length = length(first_id:last_id)
#            for colname in propertynames(df)
#                colname == :DateTime && continue
#                if meta.end_of_interval_step == 1 # indicates RH
#                    col = ones(result_length) .* df[!, colname][1] # realization is first period setpoint
#                else
#                    col = df[!, colname][first_id:last_id]
#                end
#                if !haskey(results_concat, colname)
#                    results_concat[colname] = col
#                else
#                    results_concat[colname] = vcat(results_concat[colname], col)
#                end
#            end
#        end
#        realized_values[key] = DataFrames.DataFrame(results_concat, copycols = false)
#        DataFrames.insertcols!(realized_values[key], 1, :DateTime => timestamps)
#    end
#    return realized_values
#end

#"""
#Return the final values for the requested variable names for each time step for a problem.
#Accepts a vector of names for the return of the values. If the time stamps and names are
#loaded using the [load_results!](@ref) function it will read from memory.
#
## Arguments
#- `names::Vector{Symbol}` : names of desired results
#- `initial_time::Dates.DateTime` : initial time of the requested results
#- `len::Int`: length of results
#"""
#function read_realized_variables(
#    res::SimulationProblemResults;
#    names::Union{Vector{Symbol}, Nothing} = nothing,
#    initial_time::Union{Nothing, Dates.DateTime} = nothing,
#    len::Union{Int, Nothing} = nothing,
#)
#    names = isnothing(names) ? collect(keys(res.variable_values)) : names
#    meta = RealizedMeta(res, initial_time = initial_time, len = len)
#    result_values = read_variables(
#        res,
#        names = names,
#        initial_time = meta.initial_time,
#        count = meta.count,
#    )
#    timestamps = get_realized_timestamps(res, initial_time = initial_time, len = len)
#    return get_realization(result_values, meta, timestamps)
#end
#
#"""
#Return the final values for the requested parameter names for each time step for a problem.
#If the time stamps and names are loaded using the [load_results!](@ref) function
#it will read from memory.
#
## Arguments
#- `names::Vector{Symbol}` : names of desired results
#- `initial_time::Dates.DateTime` : initial time of the requested results
#- `len::Int`: length of results
#"""
#function read_realized_parameters(
#    res::SimulationProblemResults;
#    names::Union{Vector{Symbol}, Nothing} = nothing,
#    initial_time::Union{Nothing, Dates.DateTime} = nothing,
#    len::Union{Int, Nothing} = nothing,
#)
#    names = isnothing(names) ? collect(keys(res.parameter_values)) : names
#    meta = RealizedMeta(res, initial_time = initial_time, len = len)
#    result_values = read_parameters(
#        res,
#        names = names,
#        initial_time = meta.initial_time,
#        count = meta.count,
#    )
#    timestamps = get_realized_timestamps(res, initial_time = initial_time, len = len)
#    return get_realization(result_values, meta, timestamps)
#end
#
#"""
#Return the final values for the requested dual names for each time step for a problem.
#Accepts a vector of names for the return of the values. If the time stamps and names are
#loaded using the [load_results!](@ref) function it will read from memory.
#
## Arguments
#- `names::Vector{Tuple}` : names of desired results
#- `initial_time::Dates.DateTime` : initial time of the requested results
#- `len::Int`: length of results
#"""
#function read_realized_duals( # TODO: Should this be get_realized_duals_values?
#    res::SimulationProblemResults;
#    names::Union{Vector{Symbol}, Nothing} = nothing,
#    initial_time::Union{Nothing, Dates.DateTime} = nothing,
#    len::Union{Int, Nothing} = nothing,
#)
#    names = isnothing(names) ? collect(keys(res.dual_values)) : names
#    meta = RealizedMeta(res, initial_time = initial_time, len = len)
#    result_values =
#        read_duals(res, names = names, initial_time = meta.initial_time, count = meta.count)
#    timestamps = get_realized_timestamps(res, initial_time = initial_time, len = len)
#    return get_realization(result_values, meta, timestamps)
#end

"""
    Loads the simulation results into memory for repeated reads. Running this function twice
    overwrites the previously loaded results. This is useful when loading results from remote
    locations over network connections

    # Required Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
    # Accepted Key Words
    - `variables::Vector{Symbol}`: Variables names to load into results
    - `duals::Vector{Symbol}`: Dual names to load into results
    - `parameters::Vector{Symbol}`: Parameter names to load into results
"""
function load_results!(
    res::SimulationProblemResults,
    count::Int;
    initial_time::Union{Dates.DateTime, Nothing} = nothing,
    variables::Vector{Tuple} = Vector{Tuple}(),
    duals::Vector{Tuple} = Vector{Tuple}(),
    parameters::Vector{Tuple} = Vector{Tuple}(),
)
    initial_time = initial_time === nothing ? first(get_timestamps(res)) : initial_time

    res.results_timestamps = _process_timestamps(res, initial_time, count)

    function merge_results(store)
        merge!(
            res.variable_values,
            _read_variables(res, variables, res.results_timestamps, store),
        )
        merge!(res.dual_values, _read_duals(res, duals, res.results_timestamps, store))
        merge!(
            res.parameter_values,
            _read_parameters(res, parameters, res.results_timestamps, store),
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

#= NEEDS RE-IMPLEMENTATION
""" Exports the results in the SimulationProblemResults object to  CSV files"""
function write_to_CSV(res::SimulationProblemResults; kwargs...)
    folder_path = res.results_output_folder
    if !isdir(folder_path)
        throw(IS.ConflictingInputsError("Specified path is not valid. Set up results folder."))
    end
    variables_export = Dict()
    for (k, v) in IS.get_variables(res)
        start = decode_symbol(k)[1]
        if start !== "ON" || start !== "START" || start !== "STOP"
            variables_export[k] = get_model_base_power(res) .* v
        else
            variables_export[k] = v
        end
    end
    parameters_export = Dict()
    for (p, v) in IS.get_parameters(res)
        parameters_export[p] = get_model_base_power(res) .* v
    end
    write_data(variables_export, res.timestamp, folder_path; file_type = CSV, kwargs...)
    write_optimizer_stats(IS.get_total_cost(res), folder_path)
    write_data(IS.get_timestamp(res), folder_path, "timestamp"; file_type = CSV, kwargs...)
    write_data(get_duals(res), folder_path; file_type = CSV, kwargs...)
    write_data(parameters_export, folder_path; file_type = CSV, kwargs...)
    files = readdir(folder_path)
    compute_file_hash(folder_path, files)
    @info("Files written to $folder_path folder.")
    return
end
=#
