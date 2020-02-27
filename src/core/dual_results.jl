struct DualResults <: IS.Results
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
    constraints_duals::Dict{Symbol, Any}
    results_folder::Union{Nothing, String}
    base_power::Int
end

get_res_variables(result::DualResults) = result.variables
get_cost(result::DualResults) = result.total_cost
get_log(result::DualResults) = result.optimizer_log
get_time_stamp(result::DualResults) = result.time_stamp
get_duals(result::DualResults) = result.constraints_duals
get_variables(result::DualResults) = result.dual_variables
get_base_power(results::DualResults) = Int(results.base_power)
"""This function creates the correct results struct for the context"""
function _make_results(
    variables::Dict,
    total_cost::Dict,
    optimizer_log::Dict,
    time_stamp::DataFrames.DataFrame,
    constraints_duals::Dict,
    results_folder::String,
    base_power::Int,
)
    return DualResults(
        variables,
        total_cost,
        optimizer_log,
        time_stamp,
        constraints_duals,
        results_folder,
        base_power,
    )
end

function _make_results(
    variables::Dict,
    total_cost::Dict,
    optimizer_log::Dict,
    time_stamp::DataFrames.DataFrame,
    constraints_duals::Dict,
    base_power::Int,
)
    return DualResults(
        variables,
        total_cost,
        optimizer_log,
        time_stamp,
        constraints_duals,
        nothing,
        base_power,
    )
end
# internal function to parse through the reference dictionary and grab the file paths
function _read_references(
    results::Dict,
    duals::Array,
    stage::String,
    step::Array,
    references::Dict,
    time_length::Int,
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
    time_length::Int,
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

"""
    write_results(results::DualResults)

Exports Simulation Results to the path where they come from in the results folder

# Arguments
- `results::DualResults`: results from the simulation
- `save_path::String`: folder path where the files will be written
- `results_folder`: name of the folder where the results will be written

# Accepted Key Words
- `file_type = CSV`: only CSV and featherfile are accepted
"""
function write_results(res::DualResults; kwargs...)
    folder_path = res.results_folder
    if !isdir(folder_path)
        throw(IS.ConflictingInputsError("Specified path is not valid. Set up results folder."))
    end
    _write_data(res.variables, res.time_stamp, folder_path; kwargs...)
    _write_data(res.constraints_duals, folder_path; kwargs...)
    _write_data(res.base_power, folder_path)
    _write_optimizer_log(res.optimizer_log, folder_path)
    _write_data(res.time_stamp, folder_path, "time_stamp"; kwargs...)
    files = collect(readdir(folder_path))
    compute_file_hash(folder_path, files)
    @info("Files written to $folder_path folder.")
    return
end

# writes the results to CSV files in a folder path, but they can't be read back
function write_to_CSV(results::DualResults, folder_path::String)
    write_results(results, folder_path; file_type = CSV)
end
