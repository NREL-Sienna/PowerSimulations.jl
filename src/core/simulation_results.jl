const FILE_STRUCT =
    ["data_store", "logs", "models_json", "recorder", "results", "simulation_files"]

mutable struct SimulationResults <: PSIResults
    stage::String
    base_power::Float64
    execution_path::AbstractString
    results_output_folder::String
    existing_timestamps::StepRange{Dates.DateTime, Dates.Millisecond}
    results_timestamps::Vector{Dates.DateTime}
    system::Union{Nothing, PSY.System}
    existing_variables::Array{Symbol}
    variable_values::Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}
    existing_duals::Array{Symbol}
    dual_values::Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}
    existing_parameters::Array{Symbol}
    parameter_values::Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}
end

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

# TODO:
# - Allow passing the system path if the simulation wasn't serialized
# - Handle PER-UNIT conversion of variables according to type
# - Enconde Variable/Parameter/Dual from other inputs to avoid passing Symbol

""" Holds the results of the simulation for plotting or exporting"""
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
        collect(stage_params["existing_variables"]),
        Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}(),
        collect(stage_params["existing_duals"]),
        Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}(),
        collect(stage_params["existing_params"]),
        Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}(),
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
        collect(stage_params["existing_variables"]),
        Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}(),
        collect(stage_params["existing_duals"]),
        Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}(),
        collect(stage_params["existing_params"]),
        Dict{Symbol, SortedDict{Dates.DateTime, DataFrames.DataFrame}}(),
    )
end

get_stage_name(res::SimulationResults) = res.stage
get_system(res::SimulationResults) = res.system
get_execution_path(res::SimulationResults) = res.execution_path
get_existing_variables(res::SimulationResults) = res.existing_variables
get_existing_duals(res::SimulationResults) = res.existing_duals
get_existing_parameters(res::SimulationResults) = res.existing_parameters
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
    results = Dict{Symbol, Dict{Dates.DateTime, DataFrames.DataFrame}}()
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

function _process_timestamps!(
    res::SimulationResults,
    initial_time::Dates.DateTime,
    count::Union{Int, Nothing},
)
    results_time_stamp = res.results_timestamps
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
    else
        time_stamps_union = union(res.results_timestamps, requested_range)
        if all(diff(time_stamps_union) .== get_interval(res))
            additional_timestamps = setdiff!(requested_range, results_time_stamp)
            res.results_timestamps = time_stamps_union
        else
            @info "requesting new time range"
            additional_timestamps = requested_range = res.results_timestamps
        end
    end
    @debug additional_timestamps
    return additional_timestamps
end

function _add_results!(
    res::SimulationResults,
    get_results::Function,
    field::Symbol,
    names::Vector{Symbol},
    additional_timestamps,
)
    results_dict = get_results(res)
    current_names = keys(results_dict)
    additional_names = setdiff(names, current_names)
    current_timestamps = res.results_timestamps

    if !isempty(additional_timestamps) && !isempty(additional_names)
        @info "Requested new names and times"
        #TODO: Make an efficient the expansion of the results for this case
        results_dict = _get_store_value(res, field, names, current_timestamps)
    elseif isempty(additional_timestamps) && !isempty(additional_names)
        @info "Requested new names $(additional_names)"
        additional_values =
            _get_store_value(res, field, additional_names, current_timestamps)
        merge!(results_dict, additional_values)
    elseif !isempty(additional_timestamps) && isempty(additional_names)
        @info "Requested new times"
        additional_values = _get_store_value(res, field, names, additional_timestamps)
        for (var_name, df_dict) in additional_values
            merge!(results_dict[var_name], df_dict)
        end
    elseif isempty(additional_timestamps) && isempty(additional_names)
    else
        error()
    end
    return results_dict
end

"""
    Returns the values for the requested variable names. It keeps requests when performing multiple retrievals. Accepts a vector of names for the return of the values

    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_variables_values!(
    res::SimulationResults,
    names::Vector{Symbol};
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
)
    if initial_time === nothing
        initial_time = first(get_existing_timestamps(res))
    end
    _validate_names(res, get_existing_variables, names)
    additional_timestamps = _process_timestamps!(res, initial_time, count)
    res.variable_values = _add_results!(
        res,
        get_variables,
        CONTAINER_TYPE_VARIABLES,
        names,
        additional_timestamps,
    )
    return get_variables(res)
end

"""
    Returns the values for the requested dual names. It must match the duals requested in the simulation stage definition.
    It keeps requests when performing multiple retrievals. Accepts a vector of names for the return of the values

    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_duals_values!(
    res::SimulationResults,
    names::Vector{Symbol};
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
)
    if initial_time === nothing
        initial_time = first(get_existing_timestamps(res))
    end
    _validate_names(res, get_existing_duals, names)
    additional_timestamps = _process_timestamps!(res, initial_time, count)
    res.dual_values =
        _add_results!(res, get_duals, CONTAINER_TYPE_DUALS, names, additional_timestamps)
    return get_duals(res)
end

"""
    Returns the values for the parameters used in the simulation. It keeps requests when performing multiple retrievals. Accepts a vector of names for the return of the values

    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_parameters_values!(
    res::SimulationResults,
    names::Vector{Symbol};
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    count::Union{Int, Nothing} = nothing,
)
    if initial_time === nothing
        initial_time = first(get_existing_timestamps(res))
    end
    _validate_names(res, get_existing_parameters, names)
    additional_timestamps = _process_timestamps!(res, initial_time, count)
    res.parameter_values = _add_results!(
        res,
        IS.get_parameters,
        CONTAINER_TYPE_PARAMETERS,
        names,
        additional_timestamps,
    )
    return get_parameters(res)
end

"""
    Returns the values for the requested variable name. It keeps requests when performing multiple retrievals. Accepts a variable name to return the result.

    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_variable_values!(res::SimulationResults, name::Symbol; kwargs...)
    return get_variables_values!(res, [name]; kwargs...)[name]
end

"""
    Returns the values for the requested dual name. It keeps requests when performing multiple retrievals. Accepts a dual name to return the result.
    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_dual_values!(res::SimulationResults, name::Symbol; kwargs...)
    return get_duals_values!(res, [name]; kwargs...)[name]
end

"""
    Returns the values for the requested parameter name. It keeps requests when performing multiple retrievals. Accepts a parameter name to return the result.
    # Accepted Key Words
    - `initial_time::Dates.DateTime` : initial of the requested results
    - `count::Int`: Number of results
"""
function get_parameter_values!(res::SimulationResults, name::Symbol; kwargs...)
    return get_parameters_values!(res, [name]; kwargs...)[name]
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
