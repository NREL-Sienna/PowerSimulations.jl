# TODO:
# - Allow passing the system path if the simulation wasn't serialized
# - Handle PER-UNIT conversion of variables according to type
# - Enconde Variable/Parameter/Dual from other inputs to avoid passing Symbol

const ResultsByTime = SortedDict{Dates.DateTime, DataFrames.DataFrame}
const FieldResultsByTime = Dict{Symbol, ResultsByTime}

"""Holds the results of a simulation problem for plotting or exporting"""
mutable struct ProblemResults <: PSIResults
    problem::String
    base_power::Float64
    execution_path::String
    results_output_folder::String
    existing_timestamps::StepRange{Dates.DateTime, Dates.Millisecond}
    results_timestamps::Vector{Dates.DateTime}
    system::Union{Nothing, PSY.System}
    system_uuid::Base.UUID
    resolution::Dates.TimePeriod
    forecast_horizon::Int
    variable_values::FieldResultsByTime
    dual_values::FieldResultsByTime
    parameter_values::FieldResultsByTime
end

function ProblemResults(
    store::SimulationStore,
    problem_name::AbstractString,
    problem_params::SimulationStoreProblemParams,
    sim_params::SimulationStoreParams,
    path;
    results_output_path = nothing,
)
    if results_output_path === nothing
        results_output_path = joinpath(path, "results")
    end

    time_steps = range(
        sim_params.initial_time,
        length = problem_params.num_executions * sim_params.num_steps,
        step = problem_params.interval,
    )
    name = Symbol(problem_name)
    variables = list_fields(store, name, STORE_CONTAINER_VARIABLES)
    parameters = list_fields(store, name, STORE_CONTAINER_PARAMETERS)
    duals = list_fields(store, name, STORE_CONTAINER_DUALS)

    return ProblemResults(
        problem_name,
        problem_params.base_power,
        path,
        results_output_path,
        time_steps,
        Vector{Dates.DateTime}(),
        nothing,
        problem_params.system_uuid,
        get_resolution(problem_params),
        get_horizon(problem_params),
        _fill_result_value_container(variables),
        _fill_result_value_container(duals),
        _fill_result_value_container(parameters),
    )
end

function Base.empty!(res::ProblemResults)
    foreach(empty!, _get_dicts(res))
    empty!(res.results_timestamps)
    return
end

Base.isempty(res::ProblemResults) = all(isempty, _get_dicts(res))

# This returns the number of timestamps stored in all containers.
Base.length(res::ProblemResults) = mapreduce(length, +, _get_dicts(res))

get_problem_name(res::ProblemResults) = res.problem
get_system(res::ProblemResults) = res.system
get_resolution(res::ProblemResults) = res.resolution
get_forecast_horizon(res::ProblemResults) = res.forecast_horizon
get_execution_path(res::ProblemResults) = res.execution_path
get_existing_variables(res::ProblemResults) = collect(keys(res.variable_values))
get_existing_duals(res::ProblemResults) = collect(keys(res.dual_values))
get_existing_parameters(res::ProblemResults) = collect(keys(res.parameter_values))
get_existing_timestamps(res::ProblemResults) = res.existing_timestamps
get_model_base_power(res::ProblemResults) = res.base_power
IS.get_timestamp(result::ProblemResults) = result.results_timestamps

get_interval(res::ProblemResults) = res.existing_timestamps.step
IS.get_variables(result::ProblemResults) = result.variable_values
get_duals(result::ProblemResults) = result.dual_values
IS.get_parameters(result::ProblemResults) = result.parameter_values
IS.get_base_power(result::ProblemResults) = result.base_power

"""
Return the system used for the problem. If the system hasn't already been deserialized or
set with [`set_system!`](@ref) then deserialize and store it.
"""
function get_system!(results::ProblemResults)
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
function set_system!(results::ProblemResults, system::PSY.System)
    sys_uuid = IS.get_uuid(system)
    if sys_uuid != results.system_uuid
        throw(
            IS.InvalidValue(
                "System mismatch. $sys_uuid does not match the stored value of $results.system_uuid",
            ),
        )
    end

    results.system = system
end

_get_containers(x::ProblemResults) = (x.variable_values, x.parameter_values, x.dual_values)
_get_dicts(res::ProblemResults) = (y for x in _get_containers(res) for y in values(x))

function _get_store_value(
    res::ProblemResults,
    field::Symbol,
    names::Vector{Symbol},
    timestamps,
    ::Nothing,
)
    simulation_store_path = joinpath(get_execution_path(res), "data_store")
    return h5_store_open(simulation_store_path, "r") do store
        _get_store_value(res, field, names, timestamps, store)
    end
end

function _get_store_value(
    res::ProblemResults,
    field::Symbol,
    names::Vector{Symbol},
    timestamps,
    store::SimulationStore,
)
    results = Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}()
    problem_name = Symbol(get_problem_name(res))
    problem_interval = get_interval(res)
    resolution = get_resolution(res)
    horizon = get_forecast_horizon(res)
    for name in names
        _results = SortedDict{Dates.DateTime, DataFrames.DataFrame}()
        for ts in timestamps
            out = read_result(DataFrames.DataFrame, store, problem_name, field, name, ts)
            time_col = range(ts, length = horizon, step = resolution)
            DataFrames.insertcols!(out, 1, :DateTime => time_col)
            _results[ts] = out
        end
        results[name] = _results
    end

    return results
end

function _validate_names(existing_names::Vector{Symbol}, names::Vector{Symbol})
    for name in names
        if name ∉ existing_names
            @error("$name is not stored", sort(existing_names))
            throw(IS.InvalidValue("$name is not stored"))
        end
    end
    nothing
end

function _process_timestamps(
    res::Union{ProblemResults, OperationsProblemResults},
    initial_time::Union{Nothing, Dates.DateTime},
    count::Union{Int, Nothing},
)
    if initial_time === nothing
        initial_time = first(get_existing_timestamps(res))
    end
    existing_timestamps = get_existing_timestamps(res)

    if initial_time ∉ existing_timestamps
        invalid_timestamps = [initial_time]
    else
        if count === nothing
            requested_range = [v for v in existing_timestamps if v >= initial_time]
        else
            requested_range =
                collect(range(initial_time, length = count, step = get_interval(res)))
        end
        invalid_timestamps = [v for v in requested_range if v ∉ existing_timestamps]
    end
    if !isempty(invalid_timestamps)
        @error "Timestamps $(invalid_timestamps) not stored" get_existing_timestamps(res)
        throw(IS.InvalidValue("Timestamps not stored"))
    end
    return requested_range
end

function _read_variables(res::ProblemResults, names::Vector{Symbol}, timestamps, store)
    isempty(names) && return FieldResultsByTime()
    existing_names = get_existing_variables(res)
    _validate_names(existing_names, names)
    same_time_stamps = isempty(setdiff(res.results_timestamps, timestamps))
    names_with_values = [k for (k, v) in res.variable_values if !isempty(v)]
    same_names = isempty([n for n in names if n ∉ names_with_values])
    if same_time_stamps && same_names
        @info "reading variables from SimulationsResults"
        vals = filter(p -> (p.first ∈ names), res.variable_values)
    else
        @info "reading variables from data store"
        vals = _get_store_value(res, STORE_CONTAINER_VARIABLES, names, timestamps, store)
    end
    return vals
end

"""
    Returns the values for the requested variable names. Accepts a vector of names for the
    return of the values. If the time stamps and names are loaded using the [load_results!](@ref)
    function it will read from memory.

    # Accepted Key Words
    - `names::Vector{Symbol}` : names of desired results
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
    - `store::SimulationStore`: a store that has been opened for reading
"""
function read_variables(
    res::ProblemResults;
    names::Union{Vector{Symbol}, Nothing} = nothing,
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    names = isnothing(names) ? collect(keys(res.variable_values)) : names
    timestamps = _process_timestamps(res, initial_time, count)
    values = _read_variables(res, names, timestamps, store)
    return values
end

function _read_duals(res::ProblemResults, names::Vector{Symbol}, timestamps, store)
    isempty(names) && return FieldResultsByTime()
    existing_names = get_existing_duals(res)
    _validate_names(existing_names, names)
    same_time_stamps = isempty(setdiff(res.results_timestamps, timestamps))
    names_with_values = [k for (k, v) in res.dual_values if !isempty(v)]
    same_names = isempty([n for n in names if n ∉ names_with_values])
    if same_time_stamps && same_names
        @debug "reading duals from SimulationsResults"
        vals = filter(p -> (p.first ∈ names), res.dual_values)
    else
        @debug "reading duals from data store"
        vals = _get_store_value(res, STORE_CONTAINER_DUALS, names, timestamps, store)
    end
    return vals
end

"""
    Returns the values for the requested dual names. It must match the duals requested in the simulation problem definition.
    It keeps requests when performing multiple retrievals. Accepts a vector of names for the return of the values

    # Accepted Key Words
    - `names::Vector{Symbol}` : names of desired results
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
    - `store::SimulationStore`: a store that has been opened for reading
"""
function read_duals(
    res::ProblemResults;
    names::Union{Vector{Symbol}, Nothing} = nothing,
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    names = isnothing(names) ? collect(keys(res.dual_values)) : names
    timestamps = _process_timestamps(res, initial_time, count)
    values = _read_duals(res, names, timestamps, store)
    return values
end

function _read_parameters(res::ProblemResults, names::Vector{Symbol}, timestamps, store)
    isempty(names) && return FieldResultsByTime()
    existing_names = get_existing_parameters(res)
    _validate_names(existing_names, names)
    same_time_stamps = isempty(setdiff(res.results_timestamps, timestamps))
    names_with_values = [k for (k, v) in res.parameter_values if !isempty(v)]
    same_names = isempty([n for n in names if n ∉ names_with_values])
    if same_time_stamps && same_names
        @info "reading parameters from SimulationsResults"
        vals = filter(p -> (p.first ∈ names), res.parameter_values)
    else
        @info "reading parameters from data store"
        vals = _get_store_value(res, STORE_CONTAINER_PARAMETERS, names, timestamps, store)
    end
    return vals
end

"""
    Returns the values for the parameters used in the simulation. It keeps requests when performing multiple retrievals. Accepts a vector of names for the return of the values

    # Accepted Key Words
    - `names::Vector{Symbol}` : names of desired results
    - `initial_time::Dates.DateTime` : initial time of the requested results
    - `count::Int`: Number of results
    - `store::SimulationStore`: a store that has been opened for reading
"""
function read_parameters(
    res::ProblemResults;
    names::Union{Vector{Symbol}, Nothing} = nothing,
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
    store = nothing,
)
    names = isnothing(names) ? collect(keys(res.parameter_values)) : names
    timestamps = _process_timestamps(res, initial_time, count)
    values = _read_parameters(res, names, timestamps, store)
    return values
end

"""
    Returns the values for the requested variable name. It keeps requests when performing multiple retrievals. Accepts a variable name to return the result.

    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
    - `store::SimulationStore`: a store that has been opened for reading
"""
function read_variable(
    res::Union{OperationsProblemResults, ProblemResults},
    name::Symbol;
    kwargs...,
)
    return read_variables(res; names = [name], kwargs...)[name]
end

"""
    Returns the values for the requested dual name. It keeps requests when performing multiple retrievals. Accepts a dual name to return the result.
    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
    - `store::SimulationStore`: a store that has been opened for reading
"""
function read_dual(
    res::Union{OperationsProblemResults, ProblemResults},
    name::Symbol;
    kwargs...,
)
    return read_duals(res; names = [name], kwargs...)[name]
end

"""
    Returns the values for the requested parameter name. It keeps requests when performing multiple retrievals. Accepts a parameter name to return the result.
    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function read_parameter(
    res::Union{OperationsProblemResults, ProblemResults},
    name::Symbol;
    kwargs...,
)
    return read_parameters(res; names = [name], kwargs...)[name]
end

"""
Returns the optimizer stats for the problem as a DataFrame.

# Accepted keywords
- `store::SimulationStore`: a store that has been opened for reading
"""
function read_optimizer_stats(res::ProblemResults; store = nothing)
    return _read_optimizer_stats(res, store)
end

function _read_optimizer_stats(res::ProblemResults, ::Nothing)
    h5_store_open(joinpath(get_execution_path(res), "data_store"), "r") do store
        _read_optimizer_stats(res, store)
    end
end

function _read_optimizer_stats(res::ProblemResults, store::SimulationStore)
    return read_problem_optimizer_stats(store, Symbol(res.problem))
end

struct RealizedMeta
    initial_time::Dates.DateTime
    count::Int
    start_offset::Int
    end_offset::Int
    interval_len::Int
end

function RealizedMeta(
    res::ProblemResults;
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    existing_timestamps = get_existing_timestamps(res)
    interval = existing_timestamps.step
    resolution = get_resolution(res)
    interval_len = Int(interval / resolution)
    realized_timestamps =
        get_realized_timestamps(res, initial_time = initial_time, len = len)

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

    return RealizedMeta(result_initial_time, count, start_offset, end_offset, interval_len)
end

function get_realized_timestamps(
    res::ProblemResults;
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    existing_timestamps = get_existing_timestamps(res)
    interval = existing_timestamps.step
    resolution = get_resolution(res)
    horizon = get_forecast_horizon(res)
    initial_time = isnothing(initial_time) ? first(existing_timestamps) : initial_time
    end_time =
        isnothing(len) ? last(existing_timestamps) + interval - resolution :
        initial_time + (len - 1) * resolution

    requested_range = initial_time:resolution:end_time
    available_range = first(existing_timestamps):resolution:(last(
        existing_timestamps,
    ) + (horizon - 1) * resolution)
    invalid_timestamps = setdiff(requested_range, available_range)

    if !isempty(invalid_timestamps)
        msg = "Requested time does not match available results"
        @error msg
        throw(IS.InvalidValue(msg))
    end

    return requested_range
end

function get_realization(
    result_values::Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}},
    meta::RealizedMeta,
)
    realized_values = Dict{Symbol, DataFrames.DataFrame}()
    for (key, result_value) in result_values
        results_concat = Dict{Symbol, Vector{Float64}}()
        datetime_concat = Vector{Dates.DateTime}()
        for (step, (t, df)) in enumerate(result_value)
            first_id = step > 1 ? 1 : meta.start_offset
            last_id =
                step == meta.count ? meta.interval_len - meta.end_offset : meta.interval_len
            datetime_concat = vcat(datetime_concat, df[!, :DateTime][first_id:last_id])
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
        realized_values[key] = DataFrames.DataFrame(results_concat, copycols = false)
        DataFrames.insertcols!(realized_values[key], 1, :DateTime => datetime_concat)
    end
    return realized_values
end

"""
    Returns the final values for the requested variable names for each time step for a problem.
    Accepts a vector of names for the return of the values. If the time stamps and names are
    loaded using the [load_results!](@ref) function it will read from memory.

    # Accepted Key Words
    - `names::Vector{Symbol}` : names of desired results
    - `initial_time::Dates.DateTime` : initial time of the requested results
    - `len::Int`: length of results
"""
function read_realized_variables(
    res::ProblemResults;
    names::Union{Vector{Symbol}, Nothing} = nothing,
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    names = isnothing(names) ? collect(keys(res.variable_values)) : names
    meta = RealizedMeta(res, initial_time = initial_time, len = len)
    result_values = read_variables(
        res,
        names = names,
        initial_time = meta.initial_time,
        count = meta.count,
    )
    return get_realization(result_values, meta)
end

"""
    Returns the final values for the requested parameter names for each time step for a problem.
    Accepts a vector of names for the return of the values. If the time stamps and names are
    loaded using the [load_results!](@ref) function it will read from memory.

    # Accepted Key Words
    - `names::Vector{Symbol}` : names of desired results
    - `initial_time::Dates.DateTime` : initial time of the requested results
    - `len::Int`: length of results
"""
function read_realized_parameters(
    res::ProblemResults;
    names::Union{Vector{Symbol}, Nothing} = nothing,
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    names = isnothing(names) ? collect(keys(res.parameter_values)) : names
    meta = RealizedMeta(res, initial_time = initial_time, len = len)
    result_values = read_parameters(
        res,
        names = names,
        initial_time = meta.initial_time,
        count = meta.count,
    )
    return get_realization(result_values, meta)
end

"""
    Returns the final values for the requested dual names for each time step for a problem.
    Accepts a vector of names for the return of the values. If the time stamps and names are
    loaded using the [load_results!](@ref) function it will read from memory.

    # Accepted Key Words
    - `names::Vector{Symbol}` : names of desired results
    - `initial_time::Dates.DateTime` : initial time of the requested results
    - `len::Int`: length of results
"""
function read_realized_duals( # TODO: Should this be get_realized_duals_values?
    res::ProblemResults;
    names::Union{Vector{Symbol}, Nothing} = nothing,
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    names = isnothing(names) ? collect(keys(res.dual_values)) : names
    meta = RealizedMeta(res, initial_time = initial_time, len = len)
    result_values =
        read_duals(res, names = names, initial_time = meta.initial_time, count = meta.count)
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
    - `variables::Vector{Symbol}`: Variables names to load into results
    - `duals::Vector{Symbol}`: Dual names to load into results
    - `parameters::Vector{Symbol}`: Parameter names to load into results
"""
function load_results!(
    res::ProblemResults,
    count::Int;
    initial_time::Union{Dates.DateTime, Nothing} = nothing,
    variables::Vector{Symbol} = Symbol[],
    duals::Vector{Symbol} = Symbol[],
    parameters::Vector{Symbol} = Symbol[],
)
    initial_time =
        isnothing(initial_time) ? first(get_existing_timestamps(res)) : initial_time

    res.results_timestamps = _process_timestamps(res, initial_time, count)

    simulation_store_path = joinpath(res.execution_path, "data_store")
    h5_store_open(simulation_store_path, "r") do store
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

    return nothing
end

#= NEEDS RE-IMPLEMENTATION
""" Exports the results in the ProblemResults object to  CSV files"""
function write_to_CSV(res::ProblemResults; kwargs...)
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
    write_data(variables_export, res.time_stamp, folder_path; file_type = CSV, kwargs...)
    write_optimizer_stats(IS.get_total_cost(res), folder_path)
    write_data(IS.get_timestamp(res), folder_path, "time_stamp"; file_type = CSV, kwargs...)
    write_data(get_duals(res), folder_path; file_type = CSV, kwargs...)
    write_data(parameters_export, folder_path; file_type = CSV, kwargs...)
    files = readdir(folder_path)
    compute_file_hash(folder_path, files)
    @info("Files written to $folder_path folder.")
    return
end
=#
