
"""
Creates a DataFrame from a JuMP DenseAxisArray or SparseAxisArray.

# Arguments
- `input_array`: JuMP DenseAxisArray or SparseAxisArray to convert
- `columns::Vector{Symbol}`: Required when there is only one axis which is data. Ignored if
  `input_array` includes an axis for device names.
"""
function axis_array_to_dataframe(input_array::DenseAxisArray{Float64}, columns = nothing)
    if length(axes(input_array)) == 1
        result = Vector{Float64}(undef, length(first(input_array.axes)))

        for t in input_array.axes[1]
            result[t] = input_array[t]
        end

        @assert columns !== nothing
        return DataFrames.DataFrame(columns[1] => result)

    elseif length(axes(input_array)) == 2
        result = Array{Float64, length(input_array.axes)}(
            undef,
            length(input_array.axes[2]),
            length(input_array.axes[1]),
        )
        names = Array{Symbol, 1}(undef, length(input_array.axes[1]))

        for t in input_array.axes[2], (ix, name) in enumerate(input_array.axes[1])
            result[t, ix] = input_array[name, t]
            names[ix] = Symbol(name)
        end

        return DataFrames.DataFrame(result, names)

    elseif length(axes(input_array)) == 3
        extra_dims = sum(length(axes(input_array)[2:(end - 1)]))
        extra_vars = [Symbol("S$(s)") for s in 1:extra_dims]
        result_df = DataFrames.DataFrame()
        names = vcat(extra_vars, Symbol.(axes(input_array)[1]))

        for i in input_array.axes[2]
            third_dim = collect(fill(i, size(input_array)[end]))
            result = Array{Float64, 2}(
                undef,
                length(last(input_array.axes)),
                length(first(input_array.axes)),
            )
            for t in last(input_array.axes),
                (ix, name) in enumerate(first(input_array.axes))

                result[t, ix] = input_array[name, i, t]
            end
            res = DataFrames.DataFrame(hcat(third_dim, result), :auto)
            result_df = vcat(result_df, res)
        end

        return DataFrames.rename!(result_df, names)

    else
        error("Dimension Number $(length(axes(input_array))) not Supported")
    end
end

function axis_array_to_dataframe(input_array::DenseAxisArray, columns = nothing)
    if length(axes(input_array)) == 1
        result = Vector{Float64}(undef, length(first(input_array.axes)))
        for t in input_array.axes[1]
            result[t] = jump_value(input_array[t])
        end
        @assert columns !== nothing
        return DataFrames.DataFrame(columns[1] => result)
    elseif length(axes(input_array)) == 2
        result = Array{Float64, length(input_array.axes)}(
            undef,
            length(input_array.axes[2]),
            length(input_array.axes[1]),
        )
        names = Array{Symbol, 1}(undef, length(input_array.axes[1]))

        for t in input_array.axes[2], (ix, name) in enumerate(input_array.axes[1])
            result[t, ix] = jump_value(input_array[name, t])
            names[ix] = Symbol(name)
        end

        return DataFrames.DataFrame(result, names)

    elseif length(axes(input_array)) == 3
        extra_dims = sum(length(axes(input_array)[2:(end - 1)]))
        extra_vars = [Symbol("S$(s)") for s in 1:extra_dims]
        result_df = DataFrames.DataFrame()
        names = vcat(extra_vars, Symbol.(axes(input_array)[1]))

        for i in input_array.axes[2]
            third_dim = collect(fill(i, size(input_array)[end]))
            result = Array{Float64, 2}(
                undef,
                length(last(input_array.axes)),
                length(first(input_array.axes)),
            )
            for t in last(input_array.axes),
                (ix, name) in enumerate(first(input_array.axes))

                result[t, ix] = jump_value(input_array[name, i, t])
            end
            res = DataFrames.DataFrame(hcat(third_dim, result), :auto)
            result_df = vcat(result_df, res)
        end
        return DataFrames.rename!(result_df, names)
    else
        @warn(
            "Dimension Number $(length(axes(input_array))) not Supported, returning empty DataFrame"
        )
        return DataFrames.DataFrame()
    end
end

function axis_array_to_dataframe(input_array::SparseAxisArray, columns = nothing)
    columns = Set()
    timesteps = Set{Int}()
    for k in keys(array.data)
        push!(columns, (k[1], k[2]))
        push!(timesteps, k[3])
    end

    data = Array{Float64, 2}(undef, length(timesteps), length(columns))

    for (ix, col) in enumerate(columns), t in timesteps
        data[t, ix] = array.data[(col..., t)]
    end
    return DataFrames.DataFrame(data, Symbol.(columns))
end

function axis_array_to_dataframe(input_array::Matrix{Float64}, columns)
    return DataFrames.DataFrame(input_array, columns)
end

function write_data(
    vars_results::Dict,
    time::DataFrames.DataFrame,
    save_path::AbstractString,
)
    for (k, v) in vars_results
        var = DataFrames.DataFrame()
        if size(time, 1) == size(v, 1)
            var = hcat(time, v)
        else
            var = v
        end
        file_path = joinpath(save_path, "$(k).csv")
        CSV.write(file_path, var)
    end
end

function write_data(
    data::DataFrames.DataFrame,
    save_path::AbstractString,
    file_name::String,
)
    if isfile(save_path)
        save_path = dirname(save_path)
    end
    file_path = joinpath(save_path, "$(file_name).csv")
    CSV.write(file_path, data)
    return
end

# writing a dictionary of dataframes to files
function write_data(vars_results::Dict, save_path::String; kwargs...)
    if :duals in keys(kwargs)
        name = "dual_"
    elseif :params in keys(kwargs)
        name = "parameter_"
    else
        name = ""
    end
    for (k, v) in vars_results
        file_path = joinpath(save_path, "$name$k.csv")
        if isempty(vars_results[k])
            @debug "$name$k is empty, not writing $file_path"
        else
            CSV.write(file_path, vars_results[k])
        end
    end
end
