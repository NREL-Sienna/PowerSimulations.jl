struct OperationModelResults
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict{Symbol, Any}
    optimizer_log::Dict{Symbol, Any}
    times::DataFrames.DataFrame

end

struct StackedArea
    time_range::Array
    data_matrix::Matrix
    labels::Array

end

struct BarPlot
    time_range::Array
    bar_data::Matrix
    labels::Array

end

struct StackedGeneration
    time_range::Array
    data_matrix::Matrix
    labels::Array

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

function get_stacked_plot_data(res::OperationModelResults, variable::String; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.times[!,:Range]
    variable = res.variables[Symbol(variable)]
    Alphabetical = sort!(names(variable))

    if isnothing(sort)
        variable = variable[:, Alphabetical]
    else
        variable = variable[:,sort]
    end

    data_matrix = convert(Matrix, variable)
    labels = collect(names(variable))
    legend = string.(labels)
  
    return StackedArea(time_range, data_matrix, legend)
   
end

function get_bar_plot_data(res::OperationModelResults, variable::String; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.times[!,:Range]
    variable = res.variables[Symbol(variable)]
    Alphabetical = sort!(names(variable))

    if isnothing(sort)
        variable = variable[:, Alphabetical]
    else
        variable = variable[:,sort]
    end

    data = convert(Matrix, variable)
    bar_data = sum(data, dims = 1)
    labels = collect(names(variable))
    legend = string.(labels)
  
    return BarPlot(time_range, bar_data, legend)
   
end

function get_stacked_generation_data(res::OperationModelResults; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.times[!,:Range]
    key_name = collect(keys(res.variables))
    Alphabetical = sort!(key_name)

    if !isnothing(sort)
        labels = sort
    else
        labels = Alphabetical
    end

    variable = res.variables[Symbol(labels[1])]
    data_matrix = sum(convert(Matrix, variable), dims = 2)
    legend = string.(labels)

    for i in 1:length(labels)
        if i !== 1
            variable = res.variables[Symbol(labels[i])]
            data_matrix = hcat(data_matrix, sum(convert(Matrix, variable), dims = 2))
        end
    end
 
    return StackedGeneration(time_range, data_matrix, legend)
   
end