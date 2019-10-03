struct OperationModelResults
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict{Symbol, Any}
    optimizer_log::Dict{Symbol, Any}
    time_stamp::DataFrames.DataFrame

end

function get_variable(res_model::OperationModelResults, key::Symbol)
        try
            !isnothing(res_model.variables)
        catch
            error("No variable with key $(key) has been found.")
        end
    return get(res_model.variables, key, nothing)
end

function get_optimizer_log(res_model::OperationModelResults)
    return res_model.optimizer_log
end

function get_time_stamp(res_model::OperationModelResults, key::Symbol)
    return res_model.time_stamp
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
        temp_time_stamp = Feather.read("$file_path")
        time_stamp = temp_time_stamp[1:(size(temp_time_stamp,1)-1),:]
        

        obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer[:obj_value])
        results = OperationModelResults(variable_dict, obj_value, optimizer, time_stamp)

    return results

end
function _count_time_overlap(stage::String,
                            step::Array,
                            date_range::StepRange,
                            variable::Array, 
                            references::Dict{Any,Any})
    variable_dict = Dict()
    ref_time_stamp = DataFrames.DataFrame()                    
    for l in 1:length(variable)
        date_df = references[stage][variable[l]]
        step_df = DataFrames.DataFrame(Date = Dates.DateTime[], Step = String[], File_Path = String[])

        for n in 1:length(step)
            step_df = vcat(step_df,date_df[date_df.Step .== step[n], :])
        end
        n = length(date_range)
        variable_dict[(variable[l])] = DataFrames.DataFrame()
    
        for time in date_range
            
            file_path = step_df[step_df.Date .== time, :File_Path][1]
            
            if l == 1
                time_file_path = joinpath(dirname(file_path), "time_stamp.feather")
                temp_time_stamp = DataFrames.DataFrame(Feather.read("$time_file_path"))
                t = size(temp_time_stamp, 1)
                ref_time_stamp = vcat(ref_time_stamp,temp_time_stamp[(1:t-1),:])
                
            end
        
        end
        
    end
    extra_time_length = size(unique(ref_time_stamp),1)./(length(step)+1)
    return extra_time_length
    end

function load_simulation_results(stage::String,
                                 step::Array,
                                 date_range::StepRange,
                                 variable::Array, 
                                 references::Dict{Any,Any})

    
    variable_dict = Dict()
    time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])

    extra_time_length = _count_time_overlap(stage, step, date_range, variable, references)

    for l in 1:length(variable)
        date_df = references[stage][variable[l]]
        step_df = DataFrames.DataFrame(Date = Dates.DateTime[], Step = String[], File_Path = String[])
        
        for n in 1:length(step)
            step_df = vcat(step_df,date_df[date_df.Step .== step[n], :])
        end
        n = length(date_range)
        variable_dict[(variable[l])] = DataFrames.DataFrame()
        for time in date_range
            file_path = step_df[step_df.Date .== time, :File_Path][1]
            var = Feather.read("$file_path")
            correct_var_length = size(1:(size(var,1) - extra_time_length),1)
            variable_dict[(variable[l])] = vcat(variable_dict[(variable[l])],var[1:correct_var_length,:]) 
            if l == 1
                time_file_path = joinpath(dirname(file_path), "time_stamp.feather")
                temp_time_stamp = DataFrames.DataFrame(Feather.read("$time_file_path"))
                non_overlap = size((1:size(temp_time_stamp, 1) - extra_time_length - 1),1)
                time_stamp = vcat(time_stamp,temp_time_stamp[(1:non_overlap),:])
                
            end
        end
        
    end
    
    first_file = references[stage][variable[1]]
    file_path = first_file[first_file.Date .== date_range[1], :File_Path][1]
    opt_file_path = joinpath(dirname(file_path),"optimizer_log.feather")
    optimizer = Dict{Symbol, Any}(eachcol(Feather.read("$opt_file_path"),true))
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer[:obj_value])
    results = OperationModelResults(variable_dict, obj_value, optimizer, time_stamp)

    return results

end