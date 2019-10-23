# This function returns the length of time_stamp for each step
# that is unique to that step and not overlapping with the next time step.

function _count_time_overlap(stage::String,
    step::Array,
    variable::Array, 
    references::Dict{Any,Any})


date_df = references[stage][variable[1]]
step_df = DataFrames.DataFrame(Date = Dates.DateTime[], 
           Step = String[], 
           File_Path = String[])

for n in 1:length(step)
step_df = vcat(step_df,date_df[date_df.Step .== step[n], :])

end
ref = DataFrames.DataFrame()

for (ix,time) in enumerate(step_df.Date)

try
file_path =  step_df[ix, :File_Path]
time_file_path = joinpath(dirname(file_path), "time_stamp.feather")
temp_time_stamp = DataFrames.DataFrame(Feather.read("$time_file_path"))
t = size(temp_time_stamp, 1)
append!(ref,temp_time_stamp[(1:t-1),:])

catch
@warn "The given date_range is outside the results time stamp."
end
end
if size(unique(ref),2) == size(ref,2)
extra_time_length = 0
else
extra_time_length = size(unique(ref),1)./(length(step)+1)
end
return extra_time_length
end
# This is the count_time_overlap for if all results for a stage are desired

function _count_time_overlap_all(stage::String, references::Dict{Any,Any})

variable = collect(keys(references[stage]))
date_df = references[stage][variable[1]]
ref = DataFrames.DataFrame()

for (ix,time) in enumerate(date_df.Date)

try
file_path =  date_df[ix, :File_Path]
time_file_path = joinpath(dirname(file_path), "time_stamp.feather")
temp_time_stamp = DataFrames.DataFrame(Feather.read("$time_file_path"))
t = size(temp_time_stamp, 1)
append!(ref,temp_time_stamp[(1:t-1),:])

catch
@warn "The given date_range is outside the results time stamp."
end
end
if size(unique(ref),2) == size(ref,2)
extra_time_length = 0
else
extra_time_length = size(unique(ref),1)./(length(step)+1)
end
return extra_time_length
end

"""
    results = load_simulation_results(stage, step,variable,references)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationModelResults
for the desired step range and variables

# Arguments
-`stage::String = "stage-1"``: The stage of the results getting parsed, stage-1 or stage-2
-`step::Array{String} = ["step-1", "step-2", "step-3"]`: the steps of the results getting parsed
-`variable::Array{Symbol} = [:P_ThermalStandard, :P_RenewableDispatch]`: the variables to be parsed
-`references::Dict = ref`: the reference dictionary created in run_sim_model 
or with make_references

# Example
```julia
stage = "stage-1"
step = ["step-1","step-2", "step-3"] # has to match the date range
variable = [:P_ThermalStandard, :P_RenewableDispatch]
results = load_simulation_results(stage,step, variable, references)
```
"""
function load_simulation_results(stage::String,
         step::Array,
         variable::Array, 
         references::Dict{Any,Any}; kwargs...)

variable_dict = Dict()
time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
extra_time_length = _count_time_overlap(stage, step, variable, references)

for l in 1:length(variable)

date_df = references[stage][variable[l]]
step_df = DataFrames.DataFrame(Date = Dates.DateTime[], Step = String[], File_Path = String[])       
for n in 1:length(step)
step_df = vcat(step_df,date_df[date_df.Step .== step[n], :])
end
variable_dict[(variable[l])] = DataFrames.DataFrame()

for (ix,time) in enumerate(step_df.Date)

file_path = step_df[ix, :File_Path]
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
file_path = first_file[first_file.Step .== step[1], :File_Path][1]
opt_file_path = joinpath(dirname(file_path),"optimizer_log.feather")
optimizer = Dict{Symbol, Any}(eachcol(Feather.read("$opt_file_path"),true))
obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer[:obj_value])
results = OperationModelResults(variable_dict, obj_value, optimizer, time_stamp)
if (:write in keys(kwargs)) == true
write_model_results(results, normpath("$file_path/../../../../"),"results")
end

return results

end
"""
    results = load_simulation_results(stage, references)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationModelResults

# Arguments
-`stage::String = "stage-1"`: The stage of the results getting parsed, stage-1 or stage-2
-`references::Dict = ref`: the reference dictionary created in run_sim_model 
or with make_references

# Example
```julia
stage = "stage-1"
step = ["step-1","step-2", "step-3"] # has to match the date range
variable = [:P_ThermalStandard, :P_RenewableDispatch]
results = load_simulation_results(stage,step, variable, references)
```
"""

function load_simulation_results(stage::String, references::Dict{Any,Any}; kwargs...)

variable_dict = Dict()
variable = collect(keys(references[stage]))
time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
extra_time_length = _count_time_overlap_all(stage,references)

for l in 1:length(variable)
date_df = references[stage][variable[l]]
variable_dict[(variable[l])] = DataFrames.DataFrame()

for (ix,time) in enumerate(date_df.Date)

file_path = date_df[ix, :File_Path]
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

file_path = references[stage][variable[1]][1,:File_Path]
opt_file_path = joinpath(dirname(file_path),"optimizer_log.feather")
optimizer = Dict{Symbol, Any}(eachcol(Feather.read("$opt_file_path"),true))
obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer[:obj_value])
results = OperationModelResults(variable_dict, obj_value, optimizer, time_stamp)
if (:write in keys(kwargs)) == true
    file_type = get(kwargs, :file_type, Feather)
write_model_results(results, normpath("$file_path/../../../../"),"results"; file_type = file_type)
end
return results

end