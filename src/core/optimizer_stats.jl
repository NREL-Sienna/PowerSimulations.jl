struct OptimizerStats
    simulation_step::Int
    stage_number::Int
    timestamp::Float64
    obj_value::Float64
    termination_status::Int
    primal_status::Int
    dual_status::Int
    solver_solve_time::Float64
    timed_solve_time::Float64
    solve_bytes_alloc::Union{Nothing, Float64}
    sec_in_gc::Union{Nothing, Float64}
end

function OptimizerStats(
    problem::OperationsProblem{<:PowerSimulationsOperationsProblem},
    simulation_step,
    timestamp,
    timed_log::Dict,
)
    stage_number = get_number(problem)
    model = get_jump_model(problem)
    solver_solve_time = NaN
    try
        solver_time = MOI.get(model, MOI.SolveTime())
    catch
        @warn "SolveTime() property not supported by the Solver"
    end

    return OptimizerStats(
        simulation_step,
        stage_number,
        Dates.datetime2unix(timestamp),
        JuMP.objective_value(model),
        Int(JuMP.termination_status(model)),
        Int(JuMP.primal_status(model)),
        Int(JuMP.dual_status(model)),
        solver_solve_time,
        timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc],
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
