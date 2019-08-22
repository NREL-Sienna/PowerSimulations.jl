struct OperationModelResults
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict{Symbol, Any}
    optimizer_log::Dict{Symbol, Any}
    times::DataFrames.DataFrame

end

function get_variable(res_model::OperationModelResults, key::Symbol)
        try
            !isnothing(res_model.variables)
        catch
            error("No variable has been found.")
        end
    return get(res_model.variables, key, nothing)
end

function get_optimizer_log(res_model::OperationModelResults)
    return res_model.optimizer_log
end

function get_times(res_model::OperationModelResults, key::Symbol)
    return res_model.times
end

# passing in name of folder path and the name of the folder

function load_operation_results(path::AbstractString, directory::AbstractString)

    folder_path = joinpath(path, directory)
    files_in_folder = collect(readdir(folder_path))

        variables = setdiff(files_in_folder, ["time_stamp.feather", "optimizer_log.feather"])
        variable_dict = Dict{Symbol, DataFrames.DataFrame}()

        for i in 1:length(variables)

            variable = variables[i]
            variable_name = split("$variable", ".feather")[1]
            file_path = joinpath(folder_path,"$variable_name.feather")
            variable_dict[Symbol(variable_name)] = Feather.read("$file_path") #change key to variable

        end

        file_path = joinpath(folder_path,"optimizer_log.feather")
        optimizer = Dict{Symbol, Any}(eachcol(Feather.read("$file_path"),true))

        file_path = joinpath(folder_path,"time_stamp.feather")
        time_stamp = Feather.read("$file_path")

        obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer[:obj_value])
        results = OperationModelResults(variable_dict, obj_value, optimizer, time_stamp)

    return results

end
