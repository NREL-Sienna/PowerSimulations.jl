const KNOWN_PATHS =
    ["data_store", "logs", "models_json", "recorder", "results", "simulation_files"]



function check_folder_integrity(folder::String)
    folder_files = readdir(folder)
    alien_files = [f for f in folder_files if f ∉ FILE_STRUCT]
    if isempty(alien_files)
        return true
    end
    if "data_store" ∉ folder_files
        error("The file path doesn't contain any data_store folder")
    end
    return false
end

function _results_pre_process(store::HdfSimulationStore, stage_name::Symbol)
    stage_results_params = Dict()
    store_params = get_params(store)
    sim_initial_time = get_initial_time(store_params)
    stages_params = get_stages(store_params)
    if stage_name ∉ keys(stages_params)
        error("Stage with name $(stage_name) not in the simulation")
    end
    stage_params = stages_params[stage_name]
    stage_results_params["base_power"] = get_base_power(stage_params)
    stage_results_params["system_uuid"] = get_system_uuid(stage_params)
    stage_dataset = get_dataset(store, stage_name)
    interval = get_interval(stage_params)
    executions = get_num_executions(stage_params)
    stage_results_params["existing_time_steps"] =
        range(sim_initial_time, length = executions, step = interval)
    stage_results_params["existing_variables"] = keys(get_variables(stage_dataset))
    stage_results_params["existing_params"] = keys(get_parameters(stage_dataset))
    stage_results_params["existing_duals"] = keys(get_duals(stage_dataset))
    return stage_results_params
end

function _results_pre_process(simulation_store_path::AbstractString, stage_name::String)
    stage_name = Symbol(stage_name)
    stage_params = nothing
    h5_store_open(simulation_store_path, "r") do store
        stage_params = _results_pre_process(store, stage_name)
    end
    return stage_params
end

function _fill_result_value_container(keys)
    dict = Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}()
    for k in keys
        dict[k] = SortedDict{Dates.DateTime, DataFrames.DataFrame}()
    end
    return dict
end

# TODO:
# - Allow passing the system path if the simulation wasn't serialized
# - Handle PER-UNIT conversion of variables according to type
# - Enconde Variable/Parameter/Dual from other inputs to avoid passing Symbol

""" Holds the results of the simulation for plotting or exporting"""
mutable struct SimulationResults <: PSIResults
    stage::String
    base_power::Float64
    execution_path::String
    results_output_folder::String
    existing_timestamps::StepRange{Dates.DateTime, Dates.Millisecond}
    results_timestamps::Vector{Dates.DateTime}
    system::Union{Nothing, PSY.System}
    variable_values::Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}
    dual_values::Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}
    parameter_values::Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}
end

function SimulationResults(
    path::String,
    stage_name::String;
    execution::Union{Nothing, Int} = nothing,
    load_system::Bool = true,
    results_output_path = nothing,
)
    if execution === nothing
        execution = maximum([parse(Int, f) for f in readdir(path) if occursin(r"^\d+$", f)])
    end
    execution_path = joinpath(path, string(execution))
    if !isdir(execution_path)
        error("Execution $execution not in the simulations results")
    end
    if !check_folder_integrity(execution_path)
        @warn("The results folder $(execution_path) is not consistent with the default folder structure. This can lead to errors or unwanted results")
    end
    simulation_store_path = joinpath(execution_path, "data_store")
    check_file_integrity(simulation_store_path)
    stage_params = _results_pre_process(simulation_store_path, stage_name)

    if load_system
        sys = PSY.System(joinpath(
            execution_path,
            "simulation_files",
            "system-$(stage_params["system_uuid"]).json",
        ))
    else
        sys = nothing
    end

    if results_output_path === nothing
        results_output_path = joinpath(execution_path, "results")
    end

    return SimulationResults(
        stage_name,
        stage_params["base_power"],
        execution_path,
        results_output_path,
        stage_params["existing_time_steps"],
        Vector{Dates.DateTime}(),
        sys,
        _fill_result_value_container(stage_params["existing_variables"]),
        _fill_result_value_container(stage_params["existing_duals"]),
        _fill_result_value_container(stage_params["existing_params"]),
    )
end

function SimulationResults(sim::Simulation, stage_name::String)
    simulation_store_path = get_store_dir(sim)
    check_file_integrity(simulation_store_path)
    stage_params = _results_pre_process(simulation_store_path, stage_name)
    sys = get_system(get_stage(sim, stage_name))
    return SimulationResults(
        stage_name,
        PSY.get_base_power(sys),
        get_simulation_dir(sim),
        get_results_dir(sim),
        stage_params["existing_time_steps"],
        Vector{Dates.DateTime}(),
        sys,
        _fill_result_value_container(stage_params["existing_variables"]),
        _fill_result_value_container(stage_params["existing_duals"]),
        _fill_result_value_container(stage_params["existing_params"]),
    )
end

get_stage_name(res::SimulationResults) = res.stage
get_system(res::SimulationResults) = res.system
get_execution_path(res::SimulationResults) = res.execution_path
get_existing_variables(res::SimulationResults) = collect(keys(res.variable_values))
get_existing_duals(res::SimulationResults) = collect(keys(res.dual_values))
get_existing_parameters(res::SimulationResults) = collect(keys(res.parameter_values))
get_existing_timestamps(res::SimulationResults) = res.existing_timestamps
get_model_base_power(res::SimulationResults) = res.base_power
IS.get_timestamp(result::SimulationResults) = result.results_timestamps

get_interval(res::SimulationResults) = res.existing_timestamps.step
IS.get_variables(result::SimulationResults) = result.variable_values
get_duals(result::SimulationResults) = result.dual_values
IS.get_parameters(result::SimulationResults) = result.parameter_values

#IS.get_total_cost(result::SimulationResults) = result.total_cost
#IS.get_optimizer_log(results::SimulationResults) = results.optimizer_log

function _get_store_value(
    res::SimulationResults,
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

function _validate_names(res::SimulationResults, get_existing, names::Vector{Symbol})
    for name in names
        if name ∉ get_existing(res)
            @error("$name is not stored", sort!(get_existing(res)))
            throw(IS.InvalidValue("$name is not stored"))
        end
    end
    nothing
end

function _process_timestamps(
    res::SimulationResults,
    initial_time::Union{Nothing, Dates.DateTime},
    count::Union{Int, Nothing},
)
    if initial_time === nothing
        initial_time = first(get_existing_timestamps(res))
    end
    existing_timestamps = get_existing_timestamps(res)
    if count === nothing
        requested_range = [v for v in existing_timestamps if v >= initial_time]
    else
        requested_range =
            collect(range(initial_time, length = count, step = get_interval(res)))
    end
    invalid_timestamps = [v for v in requested_range if v ∉ existing_timestamps]
    if !isempty(invalid_timestamps)
        throw(IS.InvalidValue(
            "Timetamps $(invalid_timestamps) not stored",
            sort!(get_existing_timestamps(res)),
        ))
    end
    return requested_range
end

function _get_variables_values(res::SimulationResults, names::Vector{Symbol}, timestamps)
    _validate_names(res, get_existing_variables, names)
    same_time_stamps = isempty(setdiff(res.results_timestamps, timestamps))
    existing_names = get_existing_variables(res)
    same_names = isempty([n for n in names if n ∉ existing_names])
    if !same_time_stamps && !same_names
        @debug "reading variables from data store"
        vals = _get_store_value(res, STORE_CONTAINER_VARIABLES, names, timestamps)
    else
       @debug "reading variables from SimulationsResults"
       vals =  filter(p-> (p.first ∈ names), res.variable_values)
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
    res::SimulationResults,
    names::Vector{Symbol};
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
)
    timestamps = _process_timestamps(res, initial_time, count)
    values = _get_variables_value(res, names, timestamps)
    return values
end

function _get_duals_values(res::SimulationResults, names::Vector{Symbol}, timestamps)
    _validate_names(res, get_existing_duals, names)
    return _get_store_value(res, STORE_CONTAINER_DUALS, names, timestamps)
end

"""
    Returns the values for the requested dual names. It must match the duals requested in the simulation stage definition.
    It keeps requests when performing multiple retrievals. Accepts a vector of names for the return of the values

    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_duals_values(
    res::SimulationResults,
    names::Vector{Symbol};
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
)
    timestamps = _process_timestamps(res, initial_time, count)
    values = _get_duals_values(res, names, timestamps)
    return values
end

function _get_parameters_values(res::SimulationResults, names::Vector{Symbol}, timestamps)
    _validate_names(res, get_existing_parameters, names)
    return _get_store_value(res, STORE_CONTAINER_PARAMETERS, names, timestamps)
end
"""
    Returns the values for the parameters used in the simulation. It keeps requests when performing multiple retrievals. Accepts a vector of names for the return of the values

    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_parameters_values(
    res::SimulationResults,
    names::Vector{Symbol};
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
)
    _validate_names(res, get_existing_variables, names)
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
function get_variable_values(res::SimulationResults, name::Symbol; kwargs...)
    return get_variables_values(res, [name]; kwargs...)[name]
end

"""
    Returns the values for the requested dual name. It keeps requests when performing multiple retrievals. Accepts a dual name to return the result.
    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_dual_values(res::SimulationResults, name::Symbol; kwargs...)
    return get_duals_values(res, [name]; kwargs...)[name]
end

"""
    Returns the values for the requested parameter name. It keeps requests when performing multiple retrievals. Accepts a parameter name to return the result.
    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_parameter_values(res::SimulationResults, name::Symbol; kwargs...)
    return get_parameters_values(res, [name]; kwargs...)[name]
end

function _store_result!(result_dict, results)
    for (k, v) in results
        result_dict[k] = v
    end
    return
end

"""
    Loads the simulation results into memory for repeated reads. Running this function twice
    overwrites the previously loaded results

    # Required Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
    # Accepted Key Words
    - `variables::Vector{Symbol}`: Variables names to load into results
    - `duals::Vector{Symbol}`: Dual names to load into results
    - `parameters::Vector{Symbol}`: Parameter names to load into results
"""
function load_simulation_results!(
    res::SimulationResults;
    initial_time::Dates.DateTime,
    count::Int,
    variables::Vector{Symbol} = Symbol[],
    duals::Vector{Symbol} = Symbol[],
    parameters::Vector{Symbol} = Symbol[],
)
    res.results_timestamps = _process_timestamps(res, initial_time, count)
    _store_result!(
        res.variable_values,
        _get_variables_values(res, variables, res.results_timestamps),
    )
    _store_result!(res.dual_values, _get_duals_values(res, duals, res.results_timestamps))
    _store_result!(
        res.parameter_values,
        _get_variables_values(res, parameters, res.results_timestamps),
    )
    return nothing
end

function _clear_result_dict(dict)
    for k in keys(dict)
        dict[k] = SortedDict{Dates.DateTime, DataFrames.DataFrame}()
    end
    return
end

"""
    Clears the values stored in SimulationResults
"""
function clear_simulation_results!(res::SimulationResults)
    _clear_result_dict(res.variable_values)
    _clear_result_dict(res.dual_values)
    _clear_result_dict(res.parameter_values)
    res.results_timestamps = nothing
    return
end

#= NEEDS RE-IMPLEMENTATION
""" Exports the results in the SimulationResults object to  CSV files"""
function write_to_CSV(res::SimulationResults; kwargs...)
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
