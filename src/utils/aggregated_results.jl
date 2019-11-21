struct AggregatedResults <: Results
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
    check_sum::Array
    duals::Dict{Symbol, Any}
end

get_res_variables(result::AggregatedResults) = result.variables
get_cost(result::AggregatedResults) = result.total_cost
get_log(result::AggregatedResults) = result.optimizer_log
get_time_stamp(result::AggregatedResults) = result.time_stamp
get_duals(result::AggregatedResults) = result.duals
get_variables(result::AggregatedResults) = result.dual_variables
"""This function creates the correct results struct for the context"""
function _make_results(variables::Dict,
                      total_cost::Dict,
                      optimizer_log::Dict,
                      time_stamp::DataFrames.DataFrame,
                      check_sum::Array,
                      duals::Dict)
    return AggregatedResults(variables, total_cost, optimizer_log, time_stamp, check_sum, duals)
end

# This function returns the length of time_stamp for each step
# that is unique to that step and not overlapping with the next time step.
#=
function _count_time_overlap(stage::String,
    step::Array,
    variable::Array,
    references::Dict{Any, Any})
    date_df = references[stage][variable[1]]
    step_df = DataFrames.DataFrame(Date = Dates.DateTime[],
            Step = String[],
            File_Path = String[])
    for n in 1:length(step)
        step_df = vcat(step_df, date_df[date_df.Step .== step[n], :])
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
=#
# This is the count_time_overlap for if all results for a stage are desired
#=
function _count_time_overlap(stage::String, references::Dict{Any, Any})
    variable = collect(keys(references[stage]))
    date_df = references[stage][variable[1]]
    ref = DataFrames.DataFrame()
    for (ix,time) in enumerate(date_df.Date)
        file_path =  date_df[ix, :File_Path]
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
=#
# internal function to parse through the reference dictionary and grab the file paths
function _reading_references(results::Dict, duals::Array, stage::String, step::Array,
                             references::Dict, extra_time::Int64)

    for name in (dual)
        date_df = references[stage][name]
        step_df = DataFrames.DataFrame(Date = Dates.DateTime[], Step = String[], File_Path = String[])
        for n in 1:length(step)
            step_df = vcat(step_df, date_df[date_df.Step .== step[n], :])
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
# internal function to parse through the reference dictionary and grab the file paths
function _reading_references(results::Dict, dual::Array, stage::String,
                             references::Dict, extra_time::Int64)
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
# internal function to remove the overlapping results and only use the most recent
function _removing_extra_time(file_path::String, time_length::Number)
    time_stamp = DataFrames.DataFrame()
    time_file_path = joinpath(dirname(file_path), "time_stamp.feather")
    temp_time_stamp = Feather.read("$time_file_path")
    time_stamp = vcat(time_stamp,temp_time_stamp[(1:time_length),:])
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
        shortvar = hcat(shortvar, df)
    end
    return shortvar
end
# internal function to check for duals
function _find_duals(variables::Array)
    duals = []
    for i in 1:length(variables)
        if occursin("dual", String.(variables[i]))
            duals = vcat(duals, variables[i])
        end
    end
    return duals
end
# internal function for differentiating variables from duals in file names
function _concat_string(duals::Vector{Symbol})
    duals = (String.(duals)).*"_dual"
    return duals
end