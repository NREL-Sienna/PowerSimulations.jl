struct OptimizerStats
    simulation_step::Int
    execution_index::Int
    objective_value::Float64
    termination_status::Int
    primal_status::Int
    dual_status::Int
    solver_solve_time::Float64
    timed_solve_time::Float64
    solve_bytes_alloc::Union{Nothing, Float64}
    sec_in_gc::Union{Nothing, Float64}
end

_SIMULATION_FIELDS = Set((:simulation_step, :execution_index))
_BASE_FIELDS = setdiff(fieldnames(OptimizerStats), _SIMULATION_FIELDS)

"""
Construct OptimizerStats when the DecisionModel is part of a simulation.
"""
function OptimizerStats(model, simulation_step)
    timed_log = get_solve_timed_log(model)
    execution_index = get_execution_count(model)
    model = get_jump_model(model)

    return OptimizerStats(
        simulation_step,
        execution_index,
        JuMP.objective_value(model),
        Int(JuMP.termination_status(model)),
        Int(JuMP.primal_status(model)),
        Int(JuMP.dual_status(model)),
        _get_solver_time(model),
        timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc],
    )
end

"""
Construct OptimizerStats when the DecisionModel is not part of a simulation.
"""
function OptimizerStats(model)
    timed_log = get_solve_timed_log(model)
    model = get_jump_model(model)

    return OptimizerStats(
        0,
        0,
        JuMP.objective_value(model),
        Int(JuMP.termination_status(model)),
        Int(JuMP.primal_status(model)),
        Int(JuMP.dual_status(model)),
        _get_solver_time(model),
        timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc],
    )
end

"""
Construct OptimizerStats from a vector that was serialized to HDF5.
"""
function OptimizerStats(data::Vector{Float64})
    return OptimizerStats(data...)
end

"""
Convert OptimizerStats to an array of floats that can be serialized to HDF5.
"""
function to_array(stats::OptimizerStats)
    return [Float64(getfield(stats, x)) for x in fieldnames(OptimizerStats)]
end

function to_dataframe(stats::OptimizerStats)
    df = DataFrames.DataFrame([to_namedtuple(stats)])
    if !_part_of_simulation(stats)
        DataFrames.select!(df, _BASE_FIELDS)
    end

    return df
end

function to_dict(stats::OptimizerStats)
    data = Dict()
    for field in fieldnames(typeof(stats))
        !_part_of_simulation(stats) && field in _SIMULATION_FIELDS && continue
        data[String(field)] = getfield(stats, field)
    end

    return data
end

function _get_solver_time(model)
    solver_solve_time = NaN
    try
        solver_solve_time = MOI.get(model, MOI.SolveTime())
    catch
        @warn "SolveTime() property not supported by the Solver"
    end

    return solver_solve_time
end

function get_column_names(::Type{OptimizerStats})
    return collect(string.(fieldnames(OptimizerStats)))
end

_part_of_simulation(stats::OptimizerStats) = stats.simulation_step != 0
