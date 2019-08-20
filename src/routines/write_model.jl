""" Exports the OpModel JuMP object in MathOptFormat"""
function write_op_model(op_model::OperationModel, save_path::String)
    MOF_model = MOPFM
    MOI.copy_to(MOF_model, JuMP.backend(op_model.canonical.JuMPmodel))
    MOI.write_to_file(MOF_model, save_path)

    return
   
end

# taking the outputted files for the variable DataFrame and writing them to a featherfile

function _write_variable_results(vars_results::Dict{Symbol, DataFrames.DataFrame}, save_path::AbstractString)

    for (k,v) in vars_results
         file_path = joinpath(save_path,"$(k).feather")
         Feather.write(file_path, vars_results[k])
    end

    return

end

function _write_variable_results(vars_results::OperationModel, save_path::AbstractString)

    for (k,v) in vars(vars_results.canonical)
         file_path = joinpath(save_path,"$(k).feather")
         Feather.write(file_path, _result_dataframe_vars(v))
    end

    return

end

function _write_optimizer_log(optimizer_log::Dict{Symbol, Any}, save_path::AbstractString)

    optimizer_log[:termination_status] = Int(optimizer_log[:termination_status])
    optimizer_log[:primal_status] = Int(optimizer_log[:primal_status])
    optimizer_log[:dual_status] = Int(optimizer_log[:dual_status])
    optimizer_log[:solve_time] = optimizer_log[:solve_time]

    df = DataFrames.DataFrame(optimizer_log)
    file_path = joinpath(save_path,"optimizer_log.feather")
    Feather.write(file_path, df)

    return

end

# taking the outputted files for the time_Series DataFrame and writing them to a featherfile

function _write_time_stamps(time_stamp::DataFrames.DataFrame, save_path::AbstractString)

    df = DataFrames.DataFrame(time_stamp)
    file_path = joinpath(save_path,"time_stamp.feather")
    Feather.write(file_path, df)

    return

end

# These functions are writing directly to the feather file and skipping printing to memory.

function _export_model_result(op_m::OperationModel, save_path::String)

    _write_variable_results(op_m, save_path)
    _write_time_stamps(get_time_stamp(op_m), save_path)
    
    return

end

function _export_optimizer_log(optimizer_log::Dict{Symbol, Any},
                               op_model::OperationModel,
                               path::String)

    ps_m = op_model.canonical
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

    _write_optimizer_log(optimizer_log, path)

    return

end
