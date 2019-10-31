struct OperationsProblemResults
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict{Symbol, Any}
    optimizer_log::Dict{Symbol, Any}
    time_stamp::DataFrames.DataFrame

end

function get_variable(res_model::OperationsProblemResults, key::Symbol)
        try
            !isnothing(res_model.variables)
        catch
            error("No variable with key $(key) has been found.")
        end
    return get(res_model.variables, key, nothing)
end

function get_optimizer_log(res_model::OperationsProblemResults)
    return res_model.optimizer_log
end

function get_time_stamps(res_model::OperationsProblemResults, key::Symbol)
    return res_model.time_stamp
end

"""
    results = load_operation_results(path, folder_name)

This function can be used to load results from a folder
of results from a single-step problem, or for a single foulder
within a simulation.

# Arguments
-`path::AbstractString = folder path`
-`directory::AbstractString = "2019-10-03T09-18-00"`: the foulder name that contains
feather files of the results.

# Example
```julia
results = load_operation_results("/Users/test/", "2019-10-03T09-18-00")
```
"""
function load_operation_results(path::AbstractString, directory::AbstractString)

    if isfile(path)
        path = dirname(path)
    end

    folder_path = joinpath(path, directory)
    files_in_folder = collect(readdir(folder_path))

        variables = setdiff(files_in_folder, ["time_stamp.feather", "optimizer_log.feather"])
        variable_dict = Dict{Symbol, DataFrames.DataFrame}()

        for i in 1:length(variables)

            variable = variables[i]
            variable_name = split("$variable", ".feather")[1]
            file_path = joinpath(folder_path,"$variable_name.feather")
            variable_dict[Symbol(variable_name)] = Feather.read(file_path) #change key to variable

        end

        file_path = joinpath(folder_path,"optimizer_log.feather")
        optimizer = Dict{Symbol, Any}(eachcol(Feather.read(file_path),true))

        file_path = joinpath(folder_path,"time_stamp.feather")
        temp_time_stamp = Feather.read(file_path)
        time_stamp = temp_time_stamp[1:(size(temp_time_stamp,1)-1),:]


        obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer[:obj_value])
        results = OperationsProblemResults(variable_dict, obj_value, optimizer, time_stamp)

    return results

end
