#Given the changes in syntax in ParameterJuMP and the new format to create anonymous parameters
function add_jump_parameter(jump_model::JuMP.Model, val::Number)
    param = JuMP.@variable(jump_model, variable_type = PJ.Param())
    PJ.set_value(param, val)
    return param
end

function write_data(base_power::Float64, save_path::String)
    JSON.write(joinpath(save_path, "base_power.json"), JSON.json(base_power))
    return
end

function jump_value(input::JuMP.VariableRef)::Float64
    return JuMP.value(input)
end

function jump_value(input::T)::Float64 where {T <: JuMP.AbstractJuMPScalar}
    return JuMP.value(input)
end

function jump_value(input::PJ.ParameterRef)::Float64
    return PJ.value(input)
end

function jump_value(input::JuMP.ConstraintRef)::Float64
    return JuMP.dual(input)
end

function jump_value(input::Float64)::Float64
    return input
end

function to_matrix(array::DenseAxisArray{T, 1, K}) where {T, K <: NTuple{1, Any}}
    data = jump_value.(array.data)
    data = reshape(data, length(data), 1)
    return data
end

function to_matrix(array::DenseAxisArray{T, 1, K}) where {T <: Real, K <: NTuple{1, Any}}
    data = reshape(deepcopy(array.data), length(array.data), 1)
    return data
end

function to_matrix(array::DenseAxisArray{T, 2, K}) where {T, K <: NTuple{2, Any}}
    ax = axes(array)
    data = Matrix{Float64}(undef, length(ax[2]), length(ax[1]))
    for t in ax[2], (ix, name) in enumerate(ax[1])
        data[t, ix] = jump_value(array[name, t])
    end
    return data
end

# to_matrix functions are used to convert JuMP.Containers to matrices that can be written into
# HDF5 Store.
function to_matrix(array::DenseAxisArray{T, 2, K}) where {T <: Real, K <: NTuple{2, Any}}
    return deepcopy(permutedims(array.data))
end

function to_matrix(::DenseAxisArray{T, N, K}) where {T, N, K <: NTuple{N, Any}}
    error(
        "Converting $(N)-dimensional DenseAxisArrays to matrix is currently not supported",
    )
end

function get_column_names(key::OptimizationContainerKey)
    return [encode_key_as_string(key)]
end

function get_column_names(
    key::OptimizationContainerKey,
    ::DenseAxisArray{T, 1, K},
) where {T, K <: NTuple{1, Any}}
    return get_column_names(key)
end

function get_column_names(
    ::OptimizationContainerKey,
    array::DenseAxisArray{T, 2, K},
) where {T, K <: NTuple{2, Any}}
    return string.(axes(array)[1])
end

function _get_column_names(arr::SparseAxisArray{T, N, K}) where {T, N, K <: NTuple{N, Any}}
    return sort!(collect(Set(encode_tuple_to_column(k[1:(N - 1)]) for k in keys(arr.data))))
end

function get_column_names(
    ::OptimizationContainerKey,
    array::SparseAxisArray{T, N, K},
) where {T, N, K <: NTuple{N, Any}}
    return get_column_names(array)
end

function get_column_names(array::SparseAxisArray{T, N, K}) where {T, N, K <: NTuple{N, Any}}
    return _get_column_names(array)
end

function encode_tuple_to_column(val::NTuple{N, <:AbstractString}) where {N}
    return join(val, PSI_NAME_DELIMITER)
end

function encode_tuple_to_column(val::Tuple{String, Int})
    return join(string.(val), PSI_NAME_DELIMITER)
end

function _to_matrix(
    array::SparseAxisArray{T, N, K},
    columns,
) where {T, N, K <: NTuple{N, Any}}
    timesteps = Set{Int}(k[N] for k in keys(array.data))
    data = Matrix{Float64}(undef, length(timesteps), length(columns))
    for (ix, col) in enumerate(columns), t in timesteps
        data[t, ix] = jump_value(array.data[(col..., t)])
    end
    return data
end

function to_matrix(array::SparseAxisArray{T, N, K}) where {T, N, K <: NTuple{N, Any}}
    # Don't use _get_column_names to avoid additional string conversion
    columns = sort!(unique!([k[1:(N - 1)] for k in keys(array.data)]))
    return _to_matrix(array, columns)
end

function to_dataframe(array::SparseAxisArray{T, N, K}) where {T, N, K <: NTuple{N, Any}}
    columns = _get_column_names(array)
    return DataFrames.DataFrame(_to_matrix(array, columns), columns)
end

to_matrix(array::Array) = array

"""
Returns the correct container specification for the selected type of JuMP Model
"""
function container_spec(::Type{T}, axs...) where {T <: Any}
    return DenseAxisArray{T}(undef, axs...)
end

"""
Returns the correct container specification for the selected type of JuMP Model
"""
function container_spec(::Type{Float64}, axs...)
    cont = DenseAxisArray{Float64}(undef, axs...)
    cont.data .= fill(NaN, size(cont.data))
    return cont
end

"""
Returns the correct container specification for the selected type of JuMP Model
"""
function sparse_container_spec(::Type{T}, axs...) where {T <: JuMP.AbstractJuMPScalar}
    indexes = Base.Iterators.product(axs...)
    contents = Dict{eltype(indexes), Any}(indexes .=> zero(T))
    return SparseAxisArray(contents)
end

function sparse_container_spec(::Type{T}, axs...) where {T <: Any}
    indexes = Base.Iterators.product(axs...)
    contents = Dict{eltype(indexes), Any}(indexes .=> 0.0)
    return SparseAxisArray(contents)
end

function remove_undef!(expression_array::AbstractArray)
    # iteration is deliberately unsupported for CartesianIndex
    # Makes this code a bit hacky to be able to use isassigned with an array of arbitrary size.
    for i in CartesianIndices(expression_array.data)
        if !isassigned(expression_array.data, i.I...)
            expression_array.data[i] = zero(eltype(expression_array))
        end
    end

    return expression_array
end

remove_undef!(expression_array::SparseAxisArray) = expression_array

function _calc_dimensions(
    array::DenseAxisArray,
    key::OptimizationContainerKey,
    num_rows::Int,
    horizon::Int,
)
    ax = axes(array)
    columns = get_column_names(key, array)
    # Two use cases for read:
    # 1. Read data for one execution for one device.
    # 2. Read data for one execution for all devices.
    # This will ensure that data on disk is contiguous in both cases.
    if length(ax) == 1
        dims = (horizon, 1, num_rows)
    elseif length(ax) == 2
        dims = (horizon, length(columns), num_rows)
        # elseif length(ax) == 3
        #     # TODO: untested
        #     dims = (length(ax[2]), horizon, length(columns), num_rows)
    else
        error("unsupported data size $(length(ax))")
    end

    return Dict("columns" => columns, "dims" => dims)
end

function _calc_dimensions(
    array::SparseAxisArray,
    key::OptimizationContainerKey,
    num_rows::Int,
    horizon::Int,
)
    columns = get_column_names(key, array)
    dims = (horizon, length(columns), num_rows)
    return Dict("columns" => columns, "dims" => dims)
end

"""
Run this function only when getting detailed solver stats
"""
function _summary_to_dict!(optimizer_stats::OptimizerStats, jump_model::JuMP.Model)
    # JuMP.solution_summary uses a lot of try-catch so it has a performance hit and should be opt-in
    jump_summary = JuMP.solution_summary(jump_model, verbose=false)
    # Note we don't grab all the fields from the summary because not all can be encoded as Float for HDF store
    fields = [
        :has_values, # Bool
        :has_duals, # Bool
        # Candidate solution
        :objective_bound, # Union{Missing,Float64}
        :dual_objective_value, # Union{Missing,Float64}
        # Work counters
        :barrier_iterations, # Union{Missing,Int}
        :simplex_iterations, # Union{Missing,Int}
        :node_count, # Union{Missing,Int}
    ]

    for field in fields
        field_value = getfield(jump_summary, field)
        if ismissing(field_value)
            setfield!(optimizer_stats, field, missing)
        else
            setfield!(optimizer_stats, field, field_value)
        end
    end
    return
end

function supports_milp(jump_model::JuMP.Model)
    optimizer_backend = JuMP.backend(jump_model)
    return MOI.supports_constraint(optimizer_backend, MOI.VariableIndex, MOI.ZeroOne)
end

function _get_solver_time(jump_model::JuMP.Model)
    solver_solve_time = NaN

    try_s = get!(jump_model.ext, :try_supports_solvetime, (trycatch=true, supports=true))
    if try_s.trycatch
        try
            solver_solve_time = MOI.get(jump_model, MOI.SolveTimeSec())
            jump_model.ext[:try_supports_solvetime] = (trycatch=false, supports=true)
        catch
            @debug "SolveTimeSec() property not supported by the Solver"
            jump_model.ext[:try_supports_solvetime] = (trycatch=false, supports=false)
        end
    else
        if try_s.supports
            solver_solve_time = MOI.get(jump_model, MOI.SolveTimeSec())
        end
    end

    return solver_solve_time
end

function write_optimizer_stats!(optimizer_stats::OptimizerStats, jump_model::JuMP.Model)
    if JuMP.primal_status(jump_model) == MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        optimizer_stats.objective_value = JuMP.objective_value(jump_model)
    else
        optimizer_stats.objective_value = Inf
    end

    optimizer_stats.termination_status = Int(JuMP.termination_status(jump_model))
    optimizer_stats.primal_status = Int(JuMP.primal_status(jump_model))
    optimizer_stats.dual_status = Int(JuMP.dual_status(jump_model))
    optimizer_stats.result_count = JuMP.result_count(jump_model)
    optimizer_stats.solve_time = _get_solver_time(jump_model)
    if optimizer_stats.detailed_stats
        _summary_to_dict!(optimizer_stats, jump_model)
    end
    return
end

"""
Exports the JuMP object in MathOptFormat
"""
function serialize_optimization_model(jump_model::JuMP.Model, save_path::String)
    MOF_model = MOPFM(format=MOI.FileFormats.FORMAT_MOF)
    MOI.copy_to(MOF_model, JuMP.backend(jump_model))
    MOI.write_to_file(MOF_model, save_path)
    return
end

# check_conflict_status functions can't be tested on CI because free solvers don't support IIS
function check_conflict_status(
    jump_model::JuMP.Model,
    constraint_container::DenseAxisArray{JuMP.ConstraintRef},
)
    conflict_indices = Vector()
    dims = axes(constraint_container)
    for index in Iterators.product(dims...)
        if MOI.get(
            jump_model,
            MOI.ConstraintConflictStatus(),
            constraint_container[index...],
        ) != MOI.NOT_IN_CONFLICT
            push!(conflict_indices, index)
        end
    end
    return conflict_indices
end

function check_conflict_status(
    jump_model::JuMP.Model,
    constraint_container::SparseAxisArray{JuMP.ConstraintRef},
)
    conflict_indices = Vector()
    for (index, constraint) in constraint_container
        if MOI.get(jump_model, MOI.ConstraintConflictStatus(), constraint) !=
           MOI.NOT_IN_CONFLICT
            push!(conflict_indices, index)
        end
    end
    return conflict_indices
end
