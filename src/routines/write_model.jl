function write_op_model(op_model::OperationModel, path::String)
    MOF_model = MOPFM
    MOI.copy_to(MOF_model, JuMP.backend(op_model.canonical.JuMPmodel))
    MOI.write_to_file(MOF_model, path)
end

function write_results(results::OperationModelResults, save_path::String)

    new_folder = mkdir("$save_path/$(round(Dates.now(),Dates.Minute))")
    folder_path = new_folder
    write_variable_results(results.variables, folder_path) 
    write_optimizer_results(results.optimizer_log, folder_path)
    write_time_stamps(results.times, folder_path)
   
end
# taking the outputted files for the variable DataFrame and writing them to a featherfile

function write_variable_results(vars_results::Dict{Symbol, DataFrames.DataFrame}, save_path::AbstractString)

    for (k,v) in vars_results

         file_path = joinpath(save_path,"$(k).feather")
         Feather.write(file_path, vars_results[k])

    end
    return
end

# taking the outputted files for the optimizer log DataFrame and writing them to a featherfile

function write_optimizer_results(optimizer_log::Dict{Symbol, Any}, save_path::AbstractString)

    optimizer_log[:termination_status] = Int(optimizer_log[:termination_status])
    optimizer_log[:primal_status] = Int(optimizer_log[:primal_status])
    optimizer_log[:dual_status] = Int(optimizer_log[:dual_status])
    optimizer_log[:solve_time] = optimizer_log[:solve_time]

    df = DataFrames.DataFrame(optimizer_log)
    file_path = joinpath(save_path,"optimizer_log.feather")
    Feather.write(file_path, df)
    # println("feather file written to $file_path")
    
    return
end

# taking the outputted files for the time_Series DataFrame and writing them to a featherfile

function write_time_stamps(time_stamp::DataFrames.DataFrame, save_path::AbstractString)

    df = DataFrames.DataFrame(time_stamp)
    file_path = joinpath(save_path,"time_stamp.feather")
    Feather.write(file_path, df)
    
    return
end

# These functions are writing directly to the feather file and skipping printing to memory.

function write_model_result(op_m::OperationModel, path::String)

    for (k, v) in vars(op_m.canonical)

        file_path = joinpath(path,"$(k).feather")

        Feather.write(file_path, _result_dataframe(v))

    end

    return

end

# internal function to export the optimizer_log

function _export_optimizer_log(optimizer_log::Dict{Symbol, Any}, path::String)
    df = DataFrames.DataFrame(optimizer_log)

    file_path = joinpath(path,"optimizer_log.feather")

    Feather.write(file_path, df)

    return

end

# function to create the optimizer log dictionary from the optimizer and write it to feather file

function write_optimizer_log(optimizer_log::Dict{Symbol, Any}, ps_m::CanonicalModel, path::String)

    optimizer_log[:obj_value] = JuMP.objective_value(ps_m.JuMPmodel)
    optimizer_log[:termination_status] = Int(JuMP.termination_status(ps_m.JuMPmodel))
    optimizer_log[:primal_status] = Int(JuMP.primal_status(ps_m.JuMPmodel))
    optimizer_log[:dual_status] = Int(JuMP.dual_status(ps_m.JuMPmodel))
    try
        optimizer_log[:solve_time] = MOI.get(ps_m.JuMPmodel, MOI.SolveTime())
    catch
        @warn("SolveTime() property not supported by the Solver")
        optimizer_log[:solve_time] = "Not Supported by solver"
    end

    _export_optimizer_log(optimizer_log, path)

    return

end



