#Given the changes in syntax in ParameterJuMP and the new format to create anonymous parameters
function add_jump_parameter(model::JuMP.Model, val::Number)
    param = JuMP.@variable(model, variable_type = PJ.Param())
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

function to_array(array::JuMP.Containers.DenseAxisArray)
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

function to_array(array::JuMP.Containers.DenseAxisArray{<:Number})
    length(axes(array)) > 2 && error("array axes not supported: $(axes(array))")
    return permutedims(array.data)
end

function to_array(array::JuMP.Containers.SparseAxisArray)
    columns = unique([(k[1], k[3]) for k in keys(array.data)])
    # PERF: can we determine the 2-d array size?
    tmp_data = Dict{Any, Vector{Float64}}()
    for (ix, col) in enumerate(columns)
        res = values(filter(v -> first(v)[[1, 3]] == col, array.data))
        tmp_data[col] = PSI._jump_value.(res)
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
    return JuMP.Containers.DenseAxisArray{T}(undef, axs...)
end

""" Returns the correct container spec for the selected type of JuMP Model"""
function container_spec(::Type{Float64}, axs...)
    cont = JuMP.Containers.DenseAxisArray{Float64}(undef, axs...)
    cont.data .= ones(size(cont.data)) .* NaN
    return cont
end

""" Returns the correct container spec for the selected type of JuMP Model"""
function sparse_container_spec(::Type{T}, axs...) where {T <: JuMP.AbstractJuMPScalar}
    indexes = Base.Iterators.product(axs...)
    contents = Dict{eltype(indexes), Any}(indexes .=> 0.0)
    return JuMP.Containers.SparseAxisArray(contents)
end

function sparse_container_spec(::Type{T}, axs...) where {T <: Any}
    indexes = Base.Iterators.product(axs...)
    contents = Dict{eltype(indexes), Any}(indexes .=> 0.0)
    return JuMP.Containers.SparseAxisArray(contents)
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

remove_undef!(expression_array::JuMP.Containers.SparseAxisArray) = expression_array

function _calc_dimensions(
    array::JuMP.Containers.DenseAxisArray,
    name,
    num_rows::Int,
    horizon::Int,
)
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

function _calc_dimensions(
    array::JuMP.Containers.SparseAxisArray,
    name,
    num_rows::Int,
    horizon::Int,
)
    columns = unique([(k[1], k[3]) for k in keys(array.data)])
    dims = (horizon, length(columns), num_rows)
    return Dict("columns" => columns, "dims" => dims)
end
