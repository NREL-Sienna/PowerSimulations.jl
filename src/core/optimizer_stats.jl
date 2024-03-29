mutable struct OptimizerStats
    detailed_stats::Bool
    objective_value::Float64
    termination_status::Int
    primal_status::Int
    dual_status::Int
    solver_solve_time::Float64
    result_count::Int
    has_values::Bool
    has_duals::Bool
    # Candidate solution
    objective_bound::Union{Missing, Float64}
    relative_gap::Union{Missing, Float64}
    # Use missing instead of nothing so that CSV writting doesn't fail
    dual_objective_value::Union{Missing, Float64}
    # Work counters
    solve_time::Float64
    barrier_iterations::Union{Missing, Int}
    simplex_iterations::Union{Missing, Int}
    node_count::Union{Missing, Int}
    timed_solve_time::Float64
    timed_calculate_aux_variables::Float64
    timed_calculate_dual_variables::Float64
    solve_bytes_alloc::Union{Missing, Float64}
    sec_in_gc::Union{Missing, Float64}
end

function OptimizerStats()
    return OptimizerStats(
        false,
        NaN,
        -1,
        -1,
        -1,
        NaN,
        -1,
        false,
        false,
        missing,
        missing,
        missing,
        NaN,
        missing,
        missing,
        missing,
        NaN,
        0,
        0,
        missing,
        missing,
    )
end

"""
Construct OptimizerStats from a vector that was serialized to HDF5.
"""
function OptimizerStats(data::Vector{Float64})
    stats_field_count = fieldcount(OptimizerStats)

    vals = Vector(undef, stats_field_count)
    # This condition is for backwards compatibility with PSI versions prior to 0.27.1
    missing_gap_field_data = length(data) < stats_field_count
    to_missing = Set((
        :objective_bound,
        :dual_objective_value,
        :barrier_iterations,
        :simplex_iterations,
        :node_count,
        :relative_gap,
        :solve_bytes_alloc,
        :sec_in_gc,
    ))
    ix = 1
    for (i, name) in enumerate(fieldnames(OptimizerStats))
        if missing_gap_field_data && name == :relative_gap
            vals[i] = missing
            continue
        end

        if name in to_missing && isnan(data[ix])
            vals[i] = missing
        else
            vals[i] = data[ix]
        end
        ix += 1
    end
    return OptimizerStats(vals...)
end

"""
Convert OptimizerStats to a matrix of floats that can be serialized to HDF5.
"""
function to_matrix(stats::T) where {T <: OptimizerStats}
    field_values = Matrix{Float64}(undef, fieldcount(T), 1)
    for (ix, field) in enumerate(fieldnames(T))
        value = getfield(stats, field)
        field_values[ix] = ismissing(value) ? NaN : value
    end
    return field_values
end

function to_dataframe(stats::OptimizerStats)
    df = DataFrames.DataFrame([to_namedtuple(stats)])
    return df
end

function to_dict(stats::OptimizerStats)
    data = Dict()
    for field in fieldnames(typeof(stats))
        data[String(field)] = getfield(stats, field)
    end

    return data
end

function get_column_names(::Type{OptimizerStats})
    return (collect(string.(fieldnames(OptimizerStats))),)
end
