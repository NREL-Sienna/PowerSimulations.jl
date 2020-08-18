struct OptimizerStats
    simulation_step::Int
    stage_number::Int
    time_step::Int
    obj_value::Float64
    termination_status::Int
    primal_status::Int
    dual_status::Int
    solve_time::Float64
    solve_bytes_alloc::Union{Nothing, Float64}
    sec_in_gc::Union{Nothing, Float64}
end

function OptimizerStats(simulation_step, stage_number, time_step, model::JuMP.AbstractModel)
    solve_time = NaN
    try
        solve_time = MOI.get(model, MOI.SolveTime())
    catch
        @warn "SolveTime() property not supported by the Solver"
    end

    #@show JuMP.termination_status(model)
    #@show JuMP.primal_status(model)
    #@show JuMP.dual_status(model)
    return OptimizerStats(
        simulation_step,
        stage_number,
        time_step,
        JuMP.objective_value(model),
        Int(JuMP.termination_status(model)),
        Int(JuMP.primal_status(model)),
        Int(JuMP.dual_status(model)),
        solve_time,
        NaN,
        NaN,
    )
end

function get_column_names(::Type{OptimizerStats})
    return collect(string.(fieldnames(OptimizerStats)))
end

function from_array(::Type{OptimizerStats}, data::Array, columns)
    # Will need special handling if ever need support for backward compatibility.
    @assert columns == get_column_names(OptimizerStats)
    return [OptimizerStats(data[i, :]...) for i in axes(data)[1]]
end

function to_array(stats::OptimizerStats)
    return [Float64(getfield(stats, x)) for x in fieldnames(OptimizerStats)] 
end
