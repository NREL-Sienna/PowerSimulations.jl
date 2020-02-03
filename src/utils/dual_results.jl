struct DualResults <: Results
    variables::Dict{Symbol,DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
    constraints_duals::Dict{Symbol,Any}
end

get_res_variables(result::DualResults) = result.variables
get_cost(result::DualResults) = result.total_cost
get_log(result::DualResults) = result.optimizer_log
get_time_stamp(result::DualResults) = result.time_stamp
get_duals(result::DualResults) = result.constraints_duals
get_variables(result::DualResults) = result.dual_variables
"""This function creates the correct results struct for the context"""
function _make_results(
    variables::Dict,
    total_cost::Dict,
    optimizer_log::Dict,
    time_stamp::DataFrames.DataFrame,
    constraints_duals::Dict,
)
    return DualResults(variables, total_cost, optimizer_log, time_stamp, constraints_duals)
end

# internal function to parse through the reference dictionary and grab the file paths
function _read_references(
    results::Dict,
    duals::Array,
    stage::String,
    step::Array,
    references::Dict,
    time_length::Int64,
)

    for name in (duals)
        date_df = references[stage][name]
        step_df = DataFrames.DataFrame(
            Date = Dates.DateTime[],
            Step = String[],
            File_Path = String[],
        )
        for n in 1:length(step)
            step_df = vcat(step_df, date_df[date_df.Step .== step[n], :])
        end
        results[name] = DataFrames.DataFrame()
        for (ix, time) in enumerate(step_df.Date)
            file_path = step_df[ix, :File_Path]
            var = Feather.read("$file_path")
            results[name] = vcat(results[name], var[1:time_length, :])
        end
    end
    return results
end
# internal function to parse through the reference dictionary and grab the file paths
function _read_references(
    results::Dict,
    dual::Array,
    stage::String,
    references::Dict,
    time_length::Int64,
)
    for name in dual
        date_df = references[stage][name]
        results[name] = DataFrames.DataFrame()
        for (ix, time) in enumerate(date_df.Date)
            file_path = date_df[ix, :File_Path]
            var = Feather.read(file_path)
            results[name] = vcat(results[name], var[1:time_length, :])
        end
    end
    return results
end
# internal function to remove the overlapping results and only use the most recent
function _read_time(file_path::String, time_length::Number)
    time_file_path = joinpath(dirname(file_path), "time_stamp.feather")
    temp_time_stamp = Feather.read("$time_file_path")
    time_stamp = temp_time_stamp[(1:time_length), :]
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
    for i in 1:size(variable, 1)
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
    duals = (String.(duals)) .* "_dual"
    return duals
end
