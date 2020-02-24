get_results(result::IS.Results) = nothing
struct OperationsProblemResults <: IS.Results
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
end

"""This function creates the correct results struct for the context"""
function _make_results(
    variables::Dict,
    total_cost::Dict,
    optimizer_log::Dict,
    time_stamp::DataFrames.DataFrame,
)
    return OperationsProblemResults(variables, total_cost, optimizer_log, time_stamp)
end
"""This function creates the correct results struct for the context"""
function _make_results(
    variables::Dict,
    total_cost::Dict,
    optimizer_log::Dict,
    time_stamp::Array,
)
    time_stamp = DataFrames.DataFrame(Range = time_stamp)
    return OperationsProblemResults(variables, total_cost, optimizer_log, time_stamp)
end
"""This function creates the correct results struct for the context"""
function _make_results(
    variables::Dict,
    total_cost::Dict,
    optimizer_log::Dict,
    time_stamp::Array,
    constraints_duals::Dict,
)
    time_stamp = DataFrames.DataFrame(Range = time_stamp)
    return DualResults(
        variables,
        total_cost,
        optimizer_log,
        time_stamp,
        constraints_duals,
        nothing,
    )
end
function get_variable(res_model::OperationsProblemResults, key::Symbol)
    try
        !isnothing(res_model.variables)
        return get(res_model.variables, key, nothing)
    catch
        throw(ArgumentError("No variable with key $(key) has been found."))
    end
end

function get_optimizer_log(results::OperationsProblemResults)
    return results.optimizer_log
end

function get_time_stamps(results::OperationsProblemResults, key::Symbol)
    return results.time_stamp
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
    variables = Dict{Symbol, DataFrames.DataFrame}()
    duals = Dict()
    dual = _find_duals(variable_list)
    variable_list = setdiff(variable_list, dual)
    for name in variable_list
        variable_name = splitext(name)[1]
        file_path = joinpath(folder_path, name)
        variables[Symbol(variable_name)] = Feather.read(file_path)
    end
    optimizer = read_json(joinpath(folder_path, "optimizer_log.json"))
    time_stamp = Feather.read(joinpath(folder_path, "time_stamp.feather"))
    if size(time_stamp, 1) > find_var_length(variables, variable_list)
        time_stamp = shorten_time_stamp(time_stamp)
    end
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer["obj_value"])
    check_file_integrity(folder_path)
    results = _make_results(variables, obj_value, optimizer, time_stamp)
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
