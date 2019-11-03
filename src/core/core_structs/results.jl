abstract type Results end

get_results(result::Results) = nothing
struct OperationsProblemResults <: Results
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
end

get_duals(result::OperationsProblemResults) = nothing

function make_results(variables::Dict{Symbol, DataFrames.DataFrame},
                      total_cost::Dict,
                      optimizer_log::Dict,
                      time_stamp::DataFrames.DataFrame)
    return OperationsProblemResults(variables, total_cost, optimizer_log, time_stamp)
end

function make_results(variables::Dict{Symbol, DataFrames.DataFrame},
                      total_cost::Dict,
                      optimizer_log::Dict,
                      time_stamp::DataFrames.DataFrame,
                      duals::Dict{Symbol, Any})
    return AggregatedResults(variables, total_cost, optimizer_log, time_stamp, duals)
end
function get_variable(res_model::OperationsProblemResults, key::Symbol)
        try
            !isnothing(results.variables)
            return get(results.variables, key, nothing)
        catch
            error("No variable with key $(key) has been found.")
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
-`path::AbstractString = folder path`
-`directory::AbstractString = "2019-10-03T09-18-00"`: the foulder name that contains
feather files of the results.

# Example
```julia
results = load_operation_results("/Users/test/2019-10-03T09-18-00")
```
"""
function load_operation_results(folder_path::AbstractString)

    if isfile(folder_path)
        @error("not a folder path")
    end
    files_in_folder = collect(readdir(folder_path))
    variable_list = setdiff(files_in_folder, ["time_stamp.feather", "optimizer_log.json"])
    variables = Dict{Symbol, DataFrames.DataFrame}()

    for name in 1:length(variable_list)
        variable_name = splitext(variable_list[name])[1]
        file_path = joinpath(folder_path,variable_list[name])
        variables[Symbol(variable_name)] = Feather.read(file_path) #change key to variable
    end
    optimizer = JSON.parse(open(joinpath(folder_path, "optimizer_log.json")))
    time_stamp = Feather.read(joinpath(folder_path,"time_stamp.feather"))
    time_stamp = shorten_time_stamp(time_stamp)
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer["obj_value"])
    results = make_results(variables, obj_value, optimizer, time_stamp)
    return results
end

function shorten_time_stamp(time::DataFrames.DataFrame)
    time = time[1:(size(time,1)-1),:]
    return time
end
