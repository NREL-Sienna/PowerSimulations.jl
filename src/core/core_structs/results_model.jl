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
# This function returns the length of time_stamp for each step
# that is unique to that step and not overlapping with the next.

function _count_time_overlap(stage::String,
                            step::Array,
                            date_range::StepRange,
                            variable::Array, 
                            references::Dict{Any,Any})

    ref_time_stamp = DataFrames.DataFrame()                    
    date_df = references[stage][variable[1]]
    step_df = DataFrames.DataFrame(Date = Dates.DateTime[], 
                                   Step = String[], 
                                   File_Path = String[])

    for n in 1:length(step)
        step_df = vcat(step_df,date_df[date_df.Step .== step[n], :])
    end
    for time in date_range
        
        file_path = step_df[step_df.Date .== time, :File_Path][1]
        time_file_path = joinpath(dirname(file_path), "time_stamp.feather")
        temp_time_stamp = DataFrames.DataFrame(Feather.read("$time_file_path"))
        t = size(temp_time_stamp, 1)
        ref_time_stamp = vcat(ref_time_stamp,temp_time_stamp[(1:t-1),:])    

    end  
    
    extra_time_length = size(unique(ref_time_stamp),1)./(length(step)+1)
    return extra_time_length
    end

"""
    results = load_simulation_results(stage, step, date_range,variable,references)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationModelResults

**Note:** the array of steps should match the date range provided.
# Arguments
-`stage::String = "stage-1"``: The stage of the results getting parsed, stage-1 or stage-2
-`step::Array{String} = ["step-1", "step-2", "step-3"]`: the steps of the results getting parsed
-`date_range::StepRange = 2020/01/01T:00:00:00 : 2020/01/03:00:00:00`: the date range to be parsed
-`variable::Array{Symbol} = [:P_ThermalStandard, :P_RenewableDispatch]`: the variables to be parsed

# Example
```julia
date_range = (Dates.DateTime(2020, April, 4):Dates.Hour(24):Dates.DateTime(2020, April, 6))
stage = "stage-1"
step = ["step-1","step-2", "step-3"] # has to match the date range
variable = [:P_ThermalStandard, :P_RenewableDispatch]
results = load_simulation_results(stage,step, date_range, variable, references)
```
"""
function load_simulation_results(stage::String,
                                 step::Array,
                                 date_range::StepRange,
                                 variable::Array, 
                                 references::Dict{Any,Any})

    
    variable_dict = Dict()
    time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
    extra_time_length = _count_time_overlap(stage, step,
                                            date_range, variable,
                                            references)

    for l in 1:length(variable)
        date_df = references[stage][variable[l]]
        step_df = DataFrames.DataFrame(Date = Dates.DateTime[], Step = String[], File_Path = String[])
        
        for n in 1:length(step)
            step_df = vcat(step_df,date_df[date_df.Step .== step[n], :])
        end
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