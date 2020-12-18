const KNOWN_PATHS =
    ["data_store", "logs", "models_json", "recorder", "results", "simulation_files"]

function check_folder_integrity(folder::String)
    folder_files = readdir(folder)
    alien_files = [f for f in folder_files if f ∉ KNOWN_PATHS]
    if isempty(alien_files)
        return true
    end
    if "data_store" ∉ folder_files
        error("The file path doesn't contain any data_store folder")
    end
    return false
end

const ResultsByTime = SortedDict{Dates.DateTime, DataFrames.DataFrame}
const FieldResultsByTime = Dict{Symbol, ResultsByTime}

function _fill_result_value_container(fields)
    return FieldResultsByTime(x => ResultsByTime() for x in fields)
end

# TODO:
# - Allow passing the system path if the simulation wasn't serialized
# - Handle PER-UNIT conversion of variables according to type
# - Enconde Variable/Parameter/Dual from other inputs to avoid passing Symbol

"""Holds the results of a simulation stage for plotting or exporting"""
mutable struct StageResults <: PSIResults
    stage::String
    base_power::Float64
    execution_path::String
    results_output_folder::String
    existing_timestamps::StepRange{Dates.DateTime, Dates.Millisecond}
    results_timestamps::Vector{Dates.DateTime}
    system::Union{Nothing, PSY.System}
    variable_values::FieldResultsByTime
    dual_values::FieldResultsByTime
    parameter_values::FieldResultsByTime
end

function StageResults(
    store::SimulationStore,
    stage_name::AbstractString,
    stage_params::SimulationStoreStageParams,
    sim_params::SimulationStoreParams,
    path;
    load_system = true,
    results_output_path = nothing,
)
    name = Symbol(stage_name)

    if load_system
        sys = PSY.System(joinpath(
            path,
            "simulation_files",
            "system-$(stage_params.system_uuid).json",
        ))
    else
        sys = nothing
    end

    if results_output_path === nothing
        results_output_path = joinpath(path, "results")
    end

    time_steps = range(
        sim_params.initial_time,
        length = stage_params.num_executions,
        step = stage_params.interval,
    )
    variables = list_fields(store, name, STORE_CONTAINER_VARIABLES)
    parameters = list_fields(store, name, STORE_CONTAINER_PARAMETERS)
    duals = list_fields(store, name, STORE_CONTAINER_DUALS)

    return StageResults(
        stage_name,
        stage_params.base_power,
        path,
        results_output_path,
        time_steps,
        Vector{Dates.DateTime}(),
        sys,
        _fill_result_value_container(variables),
        _fill_result_value_container(duals),
        _fill_result_value_container(parameters),
    )
end

function Base.empty!(res::StageResults)
    foreach(empty!, _get_dicts(res))
    empty!(res.results_timestamps)
    return
end

Base.isempty(res::StageResults) = all(isempty, _get_dicts(res))

# This returns the number of timestamps stored in all containers.
Base.length(res::StageResults) = mapreduce(length, +, _get_dicts(res))

_get_containers(x::StageResults) = (x.variable_values, x.parameter_values, x.dual_values)
_get_dicts(res::StageResults) = (y for x in _get_containers(res) for y in values(x))
get_stage_name(res::StageResults) = res.stage
get_system(res::StageResults) = res.system
get_execution_path(res::StageResults) = res.execution_path
get_existing_variables(res::StageResults) = collect(keys(res.variable_values))
get_existing_duals(res::StageResults) = collect(keys(res.dual_values))
get_existing_parameters(res::StageResults) = collect(keys(res.parameter_values))
get_existing_timestamps(res::StageResults) = res.existing_timestamps
get_model_base_power(res::StageResults) = res.base_power
IS.get_timestamp(result::StageResults) = result.results_timestamps

get_interval(res::StageResults) = res.existing_timestamps.step
IS.get_variables(result::StageResults) = result.variable_values
get_duals(result::StageResults) = result.dual_values
IS.get_parameters(result::StageResults) = result.parameter_values

#IS.get_total_cost(result::StageResults) = result.total_cost
#IS.get_optimizer_log(results::StageResults) = results.optimizer_log

function _get_store_value(
    res::StageResults,
    field::Symbol,
    names::Vector{Symbol},
    timestamps,
)
    results = Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}()
    stage_name = Symbol(get_stage_name(res))
    simulation_store_path = joinpath(get_execution_path(res), "data_store")
    stage_interval = get_interval(res)
    h5_store_open(simulation_store_path, "r") do store
        for name in names
            _results = SortedDict{Dates.DateTime, DataFrames.DataFrame}()
            for ts in timestamps
                out = read_result(DataFrames.DataFrame, store, stage_name, field, name, ts)
                _results[ts] = out
            end
            results[name] = _results
        end
    end
    return results
end

function _validate_names(existing_names::Vector{Symbol}, names::Vector{Symbol})
    for name in names
        if name ∉ existing_names
            @error("$name is not stored", sort!(existing_names))
            throw(IS.InvalidValue("$name is not stored"))
        end
    end
    nothing
end

function _process_timestamps(
    res::StageResults,
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

function _get_variables_values(res::StageResults, names::Vector{Symbol}, timestamps)
    isempty(names) &&
        return Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}()
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
        vals = _get_store_value(res, STORE_CONTAINER_VARIABLES, names, timestamps)
    end
    return vals
end

"""
    Returns the values for the requested variable names. Accepts a vector of names for the
    return of the values. If the time stamps and names are loaded using the [load_simulation_results!](@ref)
    function it will read from memory.

    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_variables_values(
    res::StageResults,
    names::Vector{Symbol};
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
)
    timestamps = _process_timestamps(res, initial_time, count)
    values = _get_variables_values(res, names, timestamps)
    return values
end

function _get_dual_values(res::StageResults, names::Vector{Symbol}, timestamps)
    isempty(names) &&
        return Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}()
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
        vals = _get_store_value(res, STORE_CONTAINER_DUALS, names, timestamps)
    end
    return vals
end

"""
    Returns the values for the requested dual names. It must match the duals requested in the simulation stage definition.
    It keeps requests when performing multiple retrievals. Accepts a vector of names for the return of the values

    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_dual_values(
    res::StageResults,
    names::Vector{Symbol};
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
)
    timestamps = _process_timestamps(res, initial_time, count)
    values = _get_dual_values(res, names, timestamps)
    return values
end

function _get_parameters_values(res::StageResults, names::Vector{Symbol}, timestamps)
    isempty(names) &&
        return Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}()
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
        vals = _get_store_value(res, STORE_CONTAINER_PARAMETERS, names, timestamps)
    end
    return vals
end

"""
    Returns the values for the parameters used in the simulation. It keeps requests when performing multiple retrievals. Accepts a vector of names for the return of the values

    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_parameters_values(
    res::StageResults,
    names::Vector{Symbol};
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
)
    timestamps = _process_timestamps(res, initial_time, count)
    values = _get_parameters_values(res, names, timestamps)
    return values
end

"""
    Returns the values for the requested variable name. It keeps requests when performing multiple retrievals. Accepts a variable name to return the result.

    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_variable_values(res::StageResults, name::Symbol; kwargs...)
    return get_variables_values(res, [name]; kwargs...)[name]
end

"""
    Returns the values for the requested dual name. It keeps requests when performing multiple retrievals. Accepts a dual name to return the result.
    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_dual_values(res::StageResults, name::Symbol; kwargs...)
    return get_dual_values(res, [name]; kwargs...)[name]
end

"""
    Returns the values for the requested parameter name. It keeps requests when performing multiple retrievals. Accepts a parameter name to return the result.
    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_parameter_values(res::StageResults, name::Symbol; kwargs...)
    return get_parameters_values(res, [name]; kwargs...)[name]
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
function load_simulation_results!(
    res::StageResults;
    initial_time::Dates.DateTime,
    count::Int,
    variables::Vector{Symbol} = Symbol[],
    duals::Vector{Symbol} = Symbol[],
    parameters::Vector{Symbol} = Symbol[],
)
    res.results_timestamps = _process_timestamps(res, initial_time, count)
    merge!(
        res.variable_values,
        _get_variables_values(res, variables, res.results_timestamps),
    )
    merge!(res.dual_values, _get_dual_values(res, duals, res.results_timestamps))
    merge!(
        res.parameter_values,
        _get_parameters_values(res, parameters, res.results_timestamps),
    )
    return nothing
end

#= NEEDS RE-IMPLEMENTATION
""" Exports the results in the StageResults object to  CSV files"""
function write_to_CSV(res::StageResults; kwargs...)
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
    write_optimizer_log(IS.get_total_cost(res), folder_path)
    write_data(IS.get_timestamp(res), folder_path, "time_stamp"; file_type = CSV, kwargs...)
    write_data(get_duals(res), folder_path; file_type = CSV, kwargs...)
    write_data(parameters_export, folder_path; file_type = CSV, kwargs...)
    files = readdir(folder_path)
    compute_file_hash(folder_path, files)
    @info("Files written to $folder_path folder.")
    return
end
=#

struct SimulationResults <: PSIResults
    path::String
    params::SimulationStoreParams
    stage_results::Dict{String, StageResults}
end

"""
Construct SimulationResults from a path and optionally an execution number.
By default, choose the latest execution.
"""
function SimulationResults(path::AbstractString, execution = nothing)
    # path will be either the execution_path or the directory containing all executions.
    contents = readdir(path)
    if "data_store" in contents
        execution_path = path
    else
        if execution === nothing
            executions = [parse(Int, f) for f in contents if occursin(r"^\d+$", f)]
            if isempty(executions)
                error("There are no simulation results in the path")
            end
            execution = maximum(executions)
        end
        execution_path = joinpath(path, string(execution))
        if !isdir(execution_path)
            error("Execution $execution not in the simulations results")
        end
    end

    if !check_folder_integrity(execution_path)
        @warn "The results folder $(execution_path) is not consistent with the default folder structure. " *
              "This can lead to errors or unwanted results."
    end

    simulation_store_path = joinpath(execution_path, "data_store")
    check_file_integrity(simulation_store_path)

    return h5_store_open(simulation_store_path, "r") do store
        stage_results = Dict{String, StageResults}()
        sim_params = get_params(store)
        for (name, stage_params) in sim_params.stages
            name = string(name)
            stage_result =
                StageResults(store, name, stage_params, sim_params, execution_path)
            stage_results[name] = stage_result
        end

        return SimulationResults(execution_path, sim_params, stage_results)
    end
end

"""
Construct SimulationResults from a simulation.
"""
SimulationResults(sim::Simulation) = SimulationResults(get_simulation_dir(sim))

Base.empty!(res::SimulationResults) = foreach(empty!, values(res.stage_results))
Base.isempty(res::SimulationResults) = all(isempty, values(res.stage_results))
Base.length(res::SimulationResults) = mapreduce(length, +, values(res.stage_results))

function get_stage_results(results::SimulationResults, stage)
    if !haskey(results.stage_results, stage)
        throw(IS.InvalidValue("$stage is not stored"))
    end

    return results.stage_results[stage]
end

"""
Return the stage names in the simulation.
"""
list_stages(results::SimulationResults) = collect(keys(results.stage_results))
