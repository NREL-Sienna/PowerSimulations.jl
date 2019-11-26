# writing a dictionary of dataframes to files

function _write_data(vars_results::Dict{Symbol, DataFrames.DataFrame}, save_path::AbstractString; kwargs...)
    file_type = get(kwargs, :file_type, Feather)
    if file_type == Feather || file_type == CSV
        for (k,v) in vars_results
            file_path = joinpath(save_path, "$(k).$(lowercase("$file_type"))")
            file_type.write(file_path, vars_results[k])
        end
    end
    return
end

# writing a dictionary of dataframes to files and appending the time

function _write_data(vars_results::Dict{Symbol, DataFrames.DataFrame}, time::DataFrames.DataFrame, save_path::AbstractString; kwargs...)
    file_type = get(kwargs, :file_type, Feather)
    for (k,v) in vars_results
        var = DataFrames.DataFrame()
        if file_type == CSV && size(time,1) == size(v,1)
            var = hcat(time, v)
        else
            var = v
        end
        file_path = joinpath(save_path, "$(k).$(lowercase("$file_type"))")
        file_type.write(file_path, var)
    end
    return
end

function _write_data(data::DataFrames.DataFrame, save_path::AbstractString, file_name::String; kwargs...)
    if isfile(save_path)
        save_path = dirname(save_path)
    end
    file_type = get(kwargs, :file_type, Feather)
    if file_type == Feather || file_type == CSV
        file_path = joinpath(save_path, "$(file_name).$(lowercase("$file_type"))")
        file_type.write(file_path, data)
    end
    return
end


function _write_optimizer_log(optimizer_log::Dict, save_path::AbstractString)

    JSON.write(joinpath(save_path, "optimizer_log.json"), JSON.json(optimizer_log))

end

function _write_data(psi_container::PSIContainer, save_path::AbstractString; kwargs...)
    file_type = get(kwargs, :file_type, Feather)
    if file_type == Feather || file_type == CSV
        for (k, v) in get_variables(psi_container)
            file_path = joinpath(save_path, "$(k).$(lowercase("$file_type"))")
            file_type.write(file_path, _result_dataframe_variables(v))
        end
    end
    return
end

function _write_data(psi_container::PSIContainer, save_path::AbstractString, dual_con::Vector{Symbol}; kwargs...)
    file_type = get(kwargs, :file_type, Feather)
    if file_type == Feather || file_type == CSV
        duals = get_model_duals(psi_container, dual_con)
        for (k, v) in duals
            file_path = joinpath(save_path, "$(k)_dual.$(lowercase("$file_type"))")
            file_type.write(file_path, _result_dataframe_vars(v))
        end
    end
    return
end

function _write_data(op_problem::OperationsProblem, save_path::AbstractString; kwargs...)
    _write_data(op_problem.psi_container, save_path; kwargs...)
    return
end

function _write_data(stage::_Stage, save_path::AbstractString; kwargs...)
    _write_data(stage.psi_container, save_path; kwargs...)
    return
end

# These functions are writing directly to the feather file and skipping printing to memory.
function _export_model_result(stage::_Stage, start_time::Dates.DateTime, save_path::String)
    _write_data(stage, save_path)
    _write_data(get_time_stamps(stage, start_time), save_path, "time_stamp")
    return
end

function _export_model_result(stage::_Stage, start_time::Dates.DateTime, save_path::String, dual_con::Vector{Symbol})
    _write_data(stage, save_path)
    _write_data(stage, save_path, dual_con)
    _write_data(get_time_stamp(stage, start_time), save_path, "time_stamp")
    return
end

function _export_optimizer_log(optimizer_log::Dict{Symbol, Any},
                               psi_container::PSIContainer,
                               path::String)

    optimizer_log[:obj_value] = JuMP.objective_value(psi_container.JuMPmodel)
    optimizer_log[:termination_status] = Int(JuMP.termination_status(psi_container.JuMPmodel))
    optimizer_log[:primal_status] = Int(JuMP.primal_status(psi_container.JuMPmodel))
    optimizer_log[:dual_status] = Int(JuMP.dual_status(psi_container.JuMPmodel))
    try
        optimizer_log[:solve_time] = MOI.get(psi_container.JuMPmodel, MOI.SolveTime())
    catch
        @warn("SolveTime() property not supported by the Solver")
        optimizer_log[:solve_time] = NaN #"Not Supported by solver"
    end
    _write_optimizer_log(optimizer_log, path)
    return
end

"""
    write_model_results(results::Results, save_path::String)

Exports Operational Problem Results to a path

# Arguments
- `results::Results`: results from the simulation
- `save_path::String`: folder path where the files will be written

# Accepted Key Words
- `file_type = CSV`: only CSV and featherfile are accepted
"""
function write_results(results::Results, save_path::String; kwargs...)
    if !isdir(save_path)
        throw(ArgumentError("Specified path is not valid. Run write_results to save results."))
    end
    new_folder_path = replace_chars("$save_path/$(round(Dates.now(), Dates.Minute))", ":", "-")
    folder_path = mkdir(new_folder_path)
    _write_data(results.variables, folder_path; kwargs...)
    _write_optimizer_log(results.optimizer_log, folder_path)
    _write_data(results.time_stamp, folder_path, "time_stamp"; kwargs...)
    _write_results_sum(results, folder_path)
    @info("Files written to $folder_path folder.")
    return
end

"""
    write_model_results(results::AggregatedResults, save_path::String, results_folder::String)

Exports Simulation Results to the path where they come from in the results folder

# Arguments
- `results::Results`: results from the simulation
- `save_path::String`: folder path where the files will be written
- `results_folder`: name of the folder where the results will be written

# Accepted Key Words
- `file_type = CSV`: only CSV and featherfile are accepted
"""
function write_results(res::AggregatedResults, folder_path::String, results_folder::String; kwargs...)
    if !isdir(folder_path)
        throw(ArgumentError("Specified path is not valid. Run write_results to save results."))
    end
    _write_data(res.variables, res.time_stamp, folder_path; kwargs...)
    _write_data(res.duals, folder_path; kwargs...)
    _write_optimizer_log(res.optimizer_log, folder_path)
    _write_data(res.time_stamp, folder_path, "time_stamp"; kwargs...)
    _write_results_sum(res, folder_path)
    @info("Files written to $folder_path folder.")
    return
end

"""
    write_model_results(results::OperationsProblemResults, save_path::String, results_folder::String)

Exports Simulations Results to the path where they come from in the results folder

# Arguments
- `results::Results`: results from the simulation
- `save_path::String`: folder path where the files will be written
- `results_folder`: name of the folder where the results will be written

# Accepted Key Words
- `file_type = CSV`: only CSV and featherfile are accepted
"""

function write_results(res::CheckResults, folder_path::String, results_folder::String; kwargs...)
    if !isdir(folder_path)
        throw(ArgumentError("Specified path is not valid. Run write_results to save results."))
    end
    _write_data(res.variables, res.time_stamp, folder_path; kwargs...)
    _write_optimizer_log(res.optimizer_log, folder_path)
    _write_data(res.time_stamp, folder_path, "time_stamp"; kwargs...)
    _write_results_sum(res, folder_path)
    @info("Files written to $folder_path folder.")
    return
end

""" Exports the OpModel JuMP object in MathOptFormat"""
function write_op_problem(op_problem::OperationsProblem, save_path::String)
    _write_psi_container(op_problem.psi_container, save_path)
    return
end

""" Exports the OpModel JuMP object in MathOptFormat"""
function _write_psi_container(psi_container::PSIContainer, save_path::String)
    MOF_model = MOPFM()
    MOI.copy_to(MOF_model, JuMP.backend(psi_container.JuMPmodel))
    MOI.write_to_file(MOF_model, save_path)
    return
end
# sums the variable generation and writes the value to a JSON to verify
# the results were not tampered with
function _write_results_sum(results::Results, path::String)
    check_sum = _sum_variable_results(results)
    JSON.write(joinpath(path, "check_sum.json"), JSON.json(check_sum))
end
# writes the results to CSV files in a folder path, but they can't be read back
function write_to_CSV(results::OperationsProblemResults, folder_path::String)
    write_results(results, folder_path, "results"; file_type = CSV)
end
# writes the results to CSV files in a folder path, but they can't be read back
function write_to_CSV(results::AggregatedResults, folder_path::String)
    write_results(results, folder_path, "results"; file_type = CSV)
end
# writes the results to CSV files in a folder path, but they can't be read back
function write_to_CSV(results::CheckResults, folder_path::String)
    write_results(results, folder_path, "results"; file_type = CSV)
end
