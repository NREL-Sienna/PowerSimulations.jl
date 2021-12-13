#Given the changes in syntax in ParameterJuMP and the new format to create anonymous parameters
function add_jump_parameter(jump_model::JuMP.Model, val::Number)
    param = JuMP.@variable(jump_model, variable_type = PJ.Param())
    PJ.set_value(param, val)
    return param
end

function write_data(base_power::Float64, save_path::String)
    JSON.write(joinpath(save_path, "base_power.json"), JSON.json(base_power))
end

function _jump_value(input::JuMP.VariableRef)
    return JuMP.value(input)
end

function _jump_value(input::JuMP.AbstractJuMPScalar)
    return JuMP.value(input)
end

function _jump_value(input::PJ.ParameterRef)
    return PJ.value(input)
end

function _jump_value(input::JuMP.ConstraintRef)
    return JuMP.dual(input)
end

function to_array(array::JuMPDArray)
    ax = axes(array)
    len_axes = length(ax)
    if len_axes == 1
        data = _jump_value.((array[x] for x in ax[1]))
    elseif len_axes == 2
        data = Array{Float64, 2}(undef, length(ax[2]), length(ax[1]))
        for t in ax[2], (ix, name) in enumerate(ax[1])
            data[t, ix] = _jump_value(array[name, t])
        end
        # TODO: this needs a better plan
        #elseif len_axes == 3
        #    extra_dims = sum(length(axes(array)[2:(end - 1)]))
        #    arrays = Vector{Array{Float64, 2}}()

        #    for i in ax[2]
        #        third_dim = collect(fill(i, size(array)[end]))
        #        data = Array{Float64, 2}(undef, length(last(ax)), length(first(ax)))
        #        for t in last(ax), (ix, name) in enumerate(first(ax))
        #            data[t, ix] = _jump_value(array[name, i, t])
        #        end
        #        push!(arrays, data)
        #    end
        #    data = vcat(arrays)
    else
        error("array axes not supported: $(axes(array))")
    end

    return data
end

function to_array(array::JuMPDArray{<:Number})
    length(axes(array)) > 2 && error("array axes not supported: $(axes(array))")
    return permutedims(array.data)
end

function to_array(array::JuMPSparseArray)
    columns = unique([(k[1], k[3]) for k in keys(array.data)])
    # PERF: can we determine the 2-d array size?
    tmp_data = Dict{Any, Vector{Float64}}()
    for (ix, col) in enumerate(columns)
        res = values(filter(v -> first(v)[[1, 3]] == col, array.data))
        tmp_data[col] = _jump_value.(res)
    end

    data = Array{Float64, 2}(undef, length(first(values(tmp_data))), length(columns))
    for (i, column) in enumerate(columns)
        data[:, i] = tmp_data[column]
    end

    return data
end

to_array(array::Array) = array

""" Returns the correct container spec for the selected type of JuMP Model"""
function container_spec(::Type{T}, axs...) where {T <: Any}
    return JuMPDArray{T}(undef, axs...)
end

""" Returns the correct container spec for the selected type of JuMP Model"""
function container_spec(::Type{Float64}, axs...)
    cont = JuMPDArray{Float64}(undef, axs...)
    cont.data .= ones(size(cont.data)) .* NaN
    return cont
end

""" Returns the correct container spec for the selected type of JuMP Model"""
function sparse_container_spec(::Type{T}, axs...) where {T <: JuMP.AbstractJuMPScalar}
    indexes = Base.Iterators.product(axs...)
    contents = Dict{eltype(indexes), Any}(indexes .=> zero(T))
    return JuMPSparseArray(contents)
end

function sparse_container_spec(::Type{T}, axs...) where {T <: Any}
    indexes = Base.Iterators.product(axs...)
    contents = Dict{eltype(indexes), Any}(indexes .=> 0.0)
    return JuMPSparseArray(contents)
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

remove_undef!(expression_array::JuMPSparseArray) = expression_array

function _calc_dimensions(array::JuMPDArray, name, num_rows::Int, horizon::Int)
    ax = axes(array)
    # Two use cases for read:
    # 1. Read data for one execution for one device.
    # 2. Read data for one execution for all devices.
    # This will ensure that data on disk is contiguous in both cases.
    if length(ax) == 1
        columns = [name]
        dims = (horizon, 1, num_rows)
    elseif length(ax) == 2
        columns = collect(axes(array)[1])
        dims = (horizon, length(columns), num_rows)
        # elseif length(ax) == 3
        #     # TODO: untested
        #     dims = (length(ax[2]), horizon, length(columns), num_rows)
    else
        error("unsupported data size $(length(ax))")
    end

    return Dict("columns" => columns, "dims" => dims)
end

function _calc_dimensions(array::JuMPSparseArray, name, num_rows::Int, horizon::Int)
    columns = unique([(k[1], k[3]) for k in keys(array.data)])
    dims = (horizon, length(columns), num_rows)
    return Dict("columns" => columns, "dims" => dims)
end

"""
Run this function only when getting detailed solver stats
"""
function _summary_to_dict!(optimizer_stats::OptimizerStats, jump_model::JuMP.Model)
    # JuMP.solution_summary uses a lot of try-catch so it has a performance hit and should be opt-in
    jump_summary = JuMP.solution_summary(jump_model, verbose = false)
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

function _get_solver_time(jump_model::JuMP.Model)
    solver_solve_time = NaN
    try
        solver_solve_time = MOI.get(jump_model, MOI.SolveTime())
    catch
        @debug "SolveTime() property not supported by the Solver"
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

""" Exports the JuMP object in MathOptFormat"""
function serialize_optimization_model(jump_model::JuMP.Model, save_path::String)
    MOF_model = MOPFM(format = MOI.FileFormats.FORMAT_MOF)
    MOI.copy_to(MOF_model, JuMP.backend(jump_model))
    MOI.write_to_file(MOF_model, save_path)
    return
end

# check_conflict_status functions can't be tested on CI because free solvers don't support IIS
function check_conflict_status(
    jump_model::JuMP.Model,
    constraint_container::JuMPDArray{JuMP.ConstraintRef},
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
    constraint_container::JuMPSparseArray{JuMP.ConstraintRef},
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
