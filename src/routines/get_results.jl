function result_dataframe(variable::JuMP.Containers.DenseAxisArray; rounding = 2)

    result = Array{Float64,length(variable.axes)}(undef, length(variable.axes[2]), length(variable.axes[1]))
    # TODO: Remove this line once PowerSystems moves to Symbols
    names = Array{Symbol,1}(undef,length(variable.axes[1]))

    for t in variable.axes[2], (ix,name) in enumerate(variable.axes[1])

        result[t,ix] = round(JuMP.value(variable[name,t]), digits=rounding)

        names[ix] = Symbol(name)

    end

    return DataFrames.DataFrame(result, names)

end

function get_model_result(ps_m::CanonicalModel; kwargs...)

    results_df = Dict{Symbol, DataFrames.DataFrame}()

    for (k,v) in ps_m.variables

        results_df[k] = result_dataframe(v)

    end

    return results_df

end

function optimizer_log(ps_m::CanonicalModel; kwargs...)

    optimizer_log = Dict{Symbol,Any}()

    # TODO: Not all solvers can access the SolveTime() property
    #optimizer_log[:solve_time] = MOI.get(ps_m.JuMPmodel, MOI.SolveTime())
    optimizer_log[:termination_status] = JuMP.termination_status(ps_m.JuMPmodel)
    optimizer_log[:primal_status] = JuMP.primal_status(ps_m.JuMPmodel)
    optimizer_log[:dual_status] = JuMP.dual_status(ps_m.JuMPmodel)

    return optimizer_log

end