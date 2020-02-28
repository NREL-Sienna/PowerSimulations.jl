struct OperationsProblemResults <: IS.Results
    base_power::Float64
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
    results_folder::Union{Nothing, String}
    constraints_duals::Dict{Symbol, Any}
    parameter_values::Dict{Symbol, DataFrames.DataFrame}
end

get_variables(result::OperationsProblemResults) = result.variables
get_cost(result::OperationsProblemResults) = result.total_cost
get_time_stamp(result::OperationsProblemResults) = result.time_stamp
get_duals(result::OperationsProblemResults) = result.constraints_duals

function get_variable(res_model::OperationsProblemResults, key::Symbol)
    var_result = get(res_model.variables, key, nothing)
    if isnothing(var_result)
        throw(ArgumentError("No variable with key $(key) has been found."))
    end
    return var_result
end

function get_optimizer_log(results::OperationsProblemResults)
    return results.optimizer_log
end

function get_time_stamps(results::OperationsProblemResults, key::Symbol)
    return results.time_stamp
end

"""This function creates the correct results struct for the context"""
function _make_results(
    base_power::Float64,
    variables::Dict,
    total_cost::Dict,
    optimizer_log::Dict,
    time_stamp::DataFrames.DataFrame,
)
    return OperationsProblemResults(
        base_power,
        variables,
        total_cost,
        optimizer_log,
        time_stamp,
    )
end

"""
    results = load_operation_results(path)

This function can be used to load results from a folder
of results from a single-step problem, or for a single foulder
within a simulation.

# Arguments
- `path::AbstractString = folder path`
- `directory::AbstractString = "2019-10-03T09-18-00"`: the foulder name that contains
feather files of the results.

# Example
```julia
results = load_operation_results("/Users/test/2019-10-03T09-18-00")
```
"""
function load_operation_results(folder_path::AbstractString)
    if isfile(folder_path)
        throw(ArgumentError("Not a folder path."))
    end
    files_in_folder = collect(readdir(folder_path))
    variable_list = setdiff(
        files_in_folder,
        ["time_stamp.feather", "optimizer_log.json", "check.sha256"],
    )
    vars_result = Dict{Symbol, DataFrames.DataFrame}()
    dual_result = Dict{Symbol, Any}()
    dual_names = _find_duals(variable_list)
    for name in variable_list
        variable_name = splitext(name)[1]
        file_path = joinpath(folder_path, name)
        vars_result[Symbol(variable_name)] = Feather.read(file_path)
    end
    for name in dual_names
        dual_name = splitext(name)[1]
        file_path = joinpath(folder_path, name)
        dual_result[Symbol(dual_name)] = Feather.read(file_path)
    end
    optimizer_log = read_json(joinpath(folder_path, "optimizer_log.json"))
    time_stamp = Feather.read(joinpath(folder_path, "time_stamp.feather"))
    if size(time_stamp, 1) > find_var_length(vars_result, variable_list)
        time_stamp = shorten_time_stamp(time_stamp)
    end
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer_log["obj_value"])
    check_file_integrity(folder_path)
    results = OperationsProblemResults(
        base_power,
        vars_result,
        obj_value,
        optimizer_log,
        time_stamp,
        folder_path,
        dual_result,
        Dict{Symbol, DataFrames.DataFrame}(),
    )
    return results
end

# this ensures that the time_stamp is not double shortened
function find_var_length(variables::Dict, variable_list::Array)
    return size(variables[Symbol(splitext(variable_list[1])[1])], 1)
end

function shorten_time_stamp(time::DataFrames.DataFrame)
    time = time[1:(size(time, 1) - 1), :]
    return time
end

# This method is also used by OperationsProblemResults
"""
    write_results(results::IS.Results, save_path::String)

Exports Operational Problem Results to a path

# Arguments
- `results::OperationsProblemResults`: results from the simulation
- `save_path::String`: folder path where the files will be written

# Accepted Key Words
- `file_type = CSV`: only CSV and featherfile are accepted
"""
function write_results(results::OperationsProblemResults, save_path::String; kwargs...)
    if !isdir(save_path)
        throw(IS.ConflictingInputsError("Specified path is not valid. Run write_results to save results."))
    end
    folder_path = mkdir(joinpath(
        save_path,
        replace_chars("$(round(Dates.now(), Dates.Minute))", ":", "-"),
    ))
    write_data(results.variables, folder_path; kwargs...)
    if !isempty(results.constraints_duals)
        write_data(results.constraints_duals, folder_path; kwargs...)
    end
    if !isempty(results.parameter_values)
        write_data(results.parameter_values, folder_path; kwargs...)
    end
    write_data(results.base_power, folder_path)
    _write_optimizer_log(results.optimizer_log, folder_path)
    write_data(results.time_stamp, folder_path, "time_stamp"; kwargs...)
    files = collect(readdir(folder_path))
    compute_file_hash(folder_path, files)
    @info("Files written to $folder_path folder.")
    return
end

# writes the results to CSV files in a folder path, but they can't be read back
function write_to_CSV(results::OperationsProblemResults, folder_path::String)
    write_results(results, folder_path, "results"; file_type = CSV)
end
