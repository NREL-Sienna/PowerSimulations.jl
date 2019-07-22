function _result_dataframe(variable::JuMP.Containers.DenseAxisArray)

    result = Array{Float64, length(variable.axes)}(undef, length(variable.axes[2]), length(variable.axes[1]))
    # TODO: Remove this line once PowerSystems moves to Symbols
    names = Array{Symbol, 1}(undef, length(variable.axes[1]))

    for t in variable.axes[2], (ix, name) in enumerate(variable.axes[1])

        result[t, ix] = JuMP.value(variable[name, t])

        names[ix] = Symbol(name)

    end

    return DataFrames.DataFrame(result, names)

end

function get_model_result(ps_m::CanonicalModel)

    results_dict = Dict{Symbol, DataFrames.DataFrame}()

    for (k, v) in ps_m.variables

        results_dict[k] = _result_dataframe(v)

    end

    return results_dict

end

function write_model_result(ps_m::CanonicalModel, path::String)

    for (k, v) in ps_m.variables

        file_path = joinpath(path,"$(k).feather")

        Feather.write(file_path, _result_dataframe(v))

    end

    return

end

function optimizer_log!(optimizer_log::Dict{Symbol, Any}, ps_m::CanonicalModel)

    optimizer_log[:obj_value] = JuMP.objective_value(ps_m.JuMPmodel)
    optimizer_log[:termination_status] = JuMP.termination_status(ps_m.JuMPmodel)
    optimizer_log[:primal_status] = JuMP.primal_status(ps_m.JuMPmodel)
    optimizer_log[:dual_status] = JuMP.dual_status(ps_m.JuMPmodel)
    try
        optimizer_log[:solve_time] = MOI.get(ps_m.JuMPmodel, MOI.SolveTime())
    catch
        @warn("SolveTime() property not supported by the Solver")
        optimizer_log[:solve_time] = "Not Supported by solver"
    end

    return
end

function _export_optimizer_log(optimizer_log::Dict{Symbol, Any}, path::String)
    df = DataFrames.DataFrame(optimizer_log)

    file_path = joinpath(path,"optimizer_log.feather")

    Feather.write(file_path, df)

    return

end

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