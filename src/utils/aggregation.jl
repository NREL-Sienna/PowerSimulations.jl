struct AggregatedResults <: Results
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict{Symbol, Any}
    optimizer_log::Dict{Symbol, Any}
    time_stamp::DataFrames.DataFrame
    duals::Dict{Symbol, Any}
end

get_res_variables(result::AggregatedResults) = result.variables 
get_cost(result::AggregatedResults) = result.total_cost
get_log(result::AggregatedResults) = result.optimizer_log
get_time_stamp(result::AggregatedResults) = result.time_stamp
get_duals(result::AggregatedResults) = result.duals
get_variables(result::AggregatedResults) = result.dual_variables

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
        file_path =  step_df[ix, :File_Path]
        time_file_path = joinpath(dirname(file_path), "time_stamp.feather")
        time_stamp = DataFrames.DataFrame(Feather.read("$time_file_path"))
        time_stamp = shorten_time_stamp(time_stamp)
        append!(ref,time_stamp)
    end
    if size(unique(ref),2) == size(ref,2)
        extra_time_length = 0
    else
        extra_time_length = size(unique(ref),1)./(length(step)+1)
    end
    return extra_time_length
end
# This is the count_time_overlap for if all results for a stage are desired

function _count_time_overlap(stage::String, references::Dict{Any,Any})
    variable = collect(keys(references[stage]))
    date_df = references[stage][variable[1]]
    ref = DataFrames.DataFrame()
    for (ix,time) in enumerate(date_df.Date)
        file_path =  step_df[ix, :File_Path]
        time_file_path = joinpath(dirname(file_path), "time_stamp.feather")
        time_stamp = DataFrames.DataFrame(Feather.read("$time_file_path"))
        time_stamp = shorten_time_stamp(time_stamp)
        append!(ref,time_stamp)
    end
    if size(unique(ref),2) == size(ref,2)
    extra_time_length = 0
    else
    extra_time_length = size(unique(ref),1)./(length(step)+1)
    end
    return extra_time_length
end

function _reading_references(results::Dict, duals::Array, stage::String, step::Array,
                             references::DataFrames.DataFrame, extra_time::Int64)

    for name in (dual)
        date_df = references[stage][name]
        step_df = DataFrames.DataFrame(Date = Dates.DateTime[], Step = String[], File_Path = String[])       
        for n in 1:length(step)
            step_df = vcat(step_df,date_df[date_df.Step .== step[n], :])
        end
        results[name] = DataFrames.DataFrame()
        for (ix,time) in enumerate(step_df.Date)
            file_path = step_df[ix, :File_Path]
            var = Feather.read("$file_path")
            correct_var_length = size(1:(size(var,1) - extra_time),1)
            results[name] = vcat(results[name],var[1:correct_var_length,:]) 
        end
    end
    return results
end

function _reading_references(results::Dict, dual::Array, stage::String,
                             references::DataFrames.DataFrame, extra_time::Int64)
    for name in dual
        date_df = references[stage][name]
        results[name] = DataFrames.DataFrame()
        for (ix,time) in enumerate(date_df.Date)
            file_path = date_df[ix, :File_Path]
            var = Feather.read(file_path)
            correct_var_length = size(1:(size(var,1) - extra_time_length),1)
            results[name] = vcat(results[name],var[1:correct_var_length,:]) 
        end
    end
    return results
end

function _removing_extra_time(file_path::String, extra_time_length::Number)
    time_file_path = joinpath(dirname(file_path), "time_stamp.feather")
    temp_time_stamp = DataFrames.DataFrame(Feather.read("$time_file_path"))
    non_overlap = size((1:size(temp_time_stamp, 1) - extra_time_length - 1),1)
    time_stamp = vcat(time_stamp,temp_time_stamp[(1:non_overlap),:])
    return time_stamp
end

""" This sums all of the rows in a result dataframe """
function rowsum(variable::DataFrames.DataFrame, name::String)
    variable = DataFrames.DataFrame(Symbol(name) => sum.(eachcol(variable)))
    return variable
end
""" This sums each column in a result dataframe """
function columnsum(variable::DataFrames.DataFrame)
    shortvar = DataFrames.DataFrame()
    varnames = collect(names(variable))
    eachsum = (sum.(eachrow(variable)))
    for i in 1: size(variable,1)
        df = DataFrames.DataFrame(Symbol(varnames[i]) => eachsum[i])
        shortvar = hcat(shortvar,df)
    end
    return shortvar
end

function _find_duals(variables::Array)
    duals = []
    for i in 1:length(variables)
        if occursin("dual", variables[i])
            duals = vcat(duals, variables[i])
        end
    end
    return duals
end

"""
    load_simulation_results(stage, step,variable,references)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationsProblemResults
for the desired step range and variables

# Arguments
-`stage::String = "stage-1"``: The stage of the results getting parsed, stage-1 or stage-2
-`step::Array{String} = ["step-1", "step-2", "step-3"]`: the steps of the results getting parsed
-`variable::Array{Symbol} = [:P_ThermalStandard, :P_RenewableDispatch]`: the variables to be parsed
-`references::Dict = ref`: the reference dictionary created in run_simulation
or with make_references

# Example
```julia
stage = "stage-1"
step = ["step-1","step-2", "step-3"] # has to match the date range
variable = [:P_ThermalStandard, :P_RenewableDispatch]
results = load_simulation_results(stage,step, variable, references)
```
# Accepted Key Words 
-`write::Bool`: if true, the aggregated results get written back to the results
file in the folder structure
"""
function load_simulation_results(stage::String,
         step::Array,
         variable::Array,
         references::Dict{Any,Any}; kwargs...)
    variables = Dict()
    duals = Dict()
    dual = _find_duals(collect(keys(references[stage])))
    time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
    extra_time_length = _count_time_overlap(stage, step, variable, references)
    for l in 1:length(variable)
        date_df = references[stage][variable[l]]
        step_df = DataFrames.DataFrame(Date = Dates.DateTime[], Step = String[], File_Path = String[])       
        for n in 1:length(step)
            step_df = vcat(step_df,date_df[date_df.Step .== step[n], :])
        end
        variables[(variable[l])] = DataFrames.DataFrame()
        for (ix,time) in enumerate(step_df.Date)
            file_path = step_df[ix, :File_Path]
            var = Feather.read("$file_path")
            correct_var_length = size(1:(size(var,1) - extra_time_length),1)
            variables[(variable[l])] = vcat(variables[(variable[l])],var[1:correct_var_length,:]) 
            if l == 1
                time_stamp = _removing_extra_time(file_type, extra_time_length)
            end
        end
    end
    file_path = references[stage][variable[1]][1,:File_Path]
    optimizer = optimizer = JSON.parse(open(joinpath(file_path, "optimizer_log.json")))
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer[:obj_value])

    if !isempty(dual)
        duals = _reading_references(duals, dual, stage, step, references, extra_time_length)
        results = make_results(variables, obj_value, optimizer, time_stamp, duals)
    else
        results = make_results(variables, obj_value, optimizer, time_stamp)
    end
    if (:write in keys(kwargs))
        write_model_results(results, normpath("$file_path/../../../../"),"results")
    end
    return results
end

"""
    load_simulation_results(stage, references)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationsProblemResults

# Arguments
-`stage::String = "stage-1"`: The stage of the results getting parsed, stage-1 or stage-2
-`references::Dict = ref`: the reference dictionary created in run_simulation
or with make_references

# Example
```julia
stage = "stage-1"
step = ["step-1","step-2", "step-3"] # has to match the date range
variable = [:P_ThermalStandard, :P_RenewableDispatch]
results = load_simulation_results(stage,step, variable, references)
```
# Accepted Key Words 
-`write::Bool`: if true, the aggregated results get written back to the results
file in the folder structure
"""

function load_simulation_results(stage::String, references::Dict{Any,Any}; kwargs...)

    variables = Dict()
    duals = Dict()
    variable = collect(keys(references[stage]))
    dual = _find_duals(variable)
    variable = setdiff(variable,duals)
    
    time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
    extra_time_length = _count_time_overlap(stage,references)
    for l in 1:length(variable)
        date_df = references[stage][variable[l]]
        variables[(variable[l])] = DataFrames.DataFrame()
        for (ix,time) in enumerate(date_df.Date)
            file_path = date_df[ix, :File_Path]
            var = Feather.read(file_path)
            correct_var_length = size(1:(size(var,1) - extra_time_length),1)
            variables[(variable[l])] = vcat(variables[(variable[l])],var[1:correct_var_length,:]) 
            if l == 1
                time_stamp = _removing_extra_time(file_type, extra_time_length)
            end
        end
    end

    file_path = references[stage][variable[1]][1,:File_Path]
    optimizer = optimizer = JSON.parse(open(joinpath(file_path, "optimizer_log.json")))
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer[:obj_value])

    if !isepmty(dual)
        duals = _reading_references(duals, dual, stage, references, extra_time_length)
        results = make_results(variables, obj_value, optimizer, time_stamp, duals)
    else
        results = make_results(variables, obj_value, optimizer, time_stamp)
    end
    if (:write in keys(kwargs)) == true
        file_type = get(kwargs, :file_type, Feather)
        write_model_results(results, normpath("$file_path/../../../../"),"results"; file_type = file_type)
    end
    return results
end

function _concat_string(duals::Vector{Symbol})
    duals = (String.(duals)).*"_dual"
    return duals
end
""" 
    make_references(sim::Simulation, date_run::String)

Creates a dictionary of variables with a dictionary of stages
that contains dataframes of date/step/and desired file path
so that the results can be parsed sequentially by variable
and stage type.

**Note:** make_references can only be run after run_sim_model
or else, the folder structure will not yet be populated with results

# Arguments
-`sim::Simulation = sim`: simulation object created by Simulation()
-`date_run::String = "2019-10-03T09-18-00"``: the name of the file created
that contains the specific simulation run of the date run and "-test"

# Example
```julia
sim = Simulation("test", 7, stages, "/Users/lhanig/Downloads/"; 
verbose = true, system_to_file = false)
run_sim_model!(sim::Simulation; verbose::Bool = false, kwargs...)
references = make_references(sim, "2019-10-03T09-18-00-test")
```
"""
function make_references(sim::Simulation, date_run::String; kwargs...)
    sim.ref.date_ref[1] = sim.daterange[1]
    sim.ref.date_ref[2] = sim.daterange[1]
    references = Dict()
    for (ix, stage) in enumerate(sim.stages)
        variables = Dict()
        interval = PSY.get_forecasts_interval(stage.sys)
        variable_names = collect(keys(sim.stages[ix].canonical.variables))
        if :dual_constraints in keys(kwargs) && !isnothing(get_constraints(stage.canonical))
            dual_cons = _concat_string(kwargs[:dual_constraint])
            variable_names = vcat(variable_names, dual_cons)
        end
        for name in variable_names
            variables[variable_names[name]] = DataFrames.DataFrame(Date = Dates.DateTime[],
                                           Step = String[], File_Path = String[])
        end
        for s in 1:(sim.steps)
            for run in 1:stage.executions
                sim.ref.current_time = sim.ref.date_ref[ix]
                for name in variable_names
                    full_path = joinpath(sim.ref.raw, "step-$(s)-stage-$(ix)",
                                replace("$(sim.ref.current_time)",":","-"), "$(variable_names[name]).feather")
                    if isfile(full_path)
                        date_df = DataFrames.DataFrame(Date = sim.ref.current_time, 
                                                       Step = "step-$(s)", File_Path = full_path)
                        variables[variable_names[name]] = vcat(variables[variable_names[name]], date_df)
                    else
                        println("$full_path, no such file path")        
                     end
                end
                sim.ref.run_count[s][ix] += 1 
                sim.ref.date_ref[ix] = sim.ref.date_ref[ix] + interval
            end
        end
        references["stage-$ix"] = variables
        stage.execution_count = 0 
    end
    return references
end
