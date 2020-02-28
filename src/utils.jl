"""
Return a decoded JSON file.
"""
function read_json(filename::AbstractString)
    return open(filename) do io
        return JSON.parse(io)
    end
end

"""
Return the SHA 256 hash of a file.
"""
function compute_sha256(filename::AbstractString)
    return open(filename) do io
        return bytes2hex(SHA.sha256(io))
    end
end

"""
Return the key for the given value
"""
function find_key_with_value(d, value)
    for (k, v) in d
        v == value && return k
    end
    error("dict does not have value == $value")
end

function compute_file_hash(path::String, files::Vector{String})
    open(joinpath(path, "check.sha256"), "w") do io
        for file in files
            file_path = joinpath(path, file)
            hash_value = compute_sha256(file_path)
            write(io, "$hash_value    $file_path\n")
        end
    end
end

function check_kwargs(input_kwargs, valid_set::Array{Symbol}, function_name::String)
    if isempty(input_kwargs)
        return
    else
        for (key, value) in input_kwargs
            if !(key in valid_set)
                throw(ArgumentError("keyword argument $(key) is not a valid input for $(function_name)"))
            end
        end
    end
    return
end

# writing a dictionary of dataframes to files

function write_data(vars_results::Dict, save_path::String; kwargs...)
    file_type = get(kwargs, :file_type, Feather)
    if file_type == Feather || file_type == CSV
        for (k, v) in vars_results
            file_path = joinpath(save_path, "$(k).$(lowercase("$file_type"))")
            file_type.write(file_path, vars_results[k])
        end
    end
end

# writing a dictionary of dataframes to files and appending the time

function write_data(
    vars_results::Dict,
    time::DataFrames.DataFrame,
    save_path::AbstractString;
    kwargs...,
)
    file_type = get(kwargs, :file_type, Feather)
    for (k, v) in vars_results
        var = DataFrames.DataFrame()
        if file_type == CSV && size(time, 1) == size(v, 1)
            var = hcat(time, v)
        else
            var = v
        end
        file_path = joinpath(save_path, "$(k).$(lowercase("$file_type"))")
        file_type.write(file_path, var)
    end
end

function write_data(
    data::DataFrames.DataFrame,
    save_path::AbstractString,
    file_name::String;
    kwargs...,
)
    if isfile(save_path)
        save_path = dirname(save_path)
    end
    file_type = get(kwargs, :file_type, Feather)
    if file_type == Feather || file_type == CSV
        file_path = joinpath(save_path, "$(file_name).$(lowercase("$file_type"))")
        file_type.write(file_path, data)
    end
    return
end

function _write_optimizer_log(optimizer_log::Dict, save_path::AbstractString)
    JSON.write(joinpath(save_path, "optimizer_log.json"), JSON.json(optimizer_log))
end

function write_data(base_power::Float64, save_path::String)
    JSON.write(joinpath(save_path, "base_power.json"), JSON.json(base_power))
end

function result_dataframe_variables(variable::JuMP.Containers.DenseAxisArray)
    if length(axes(variable)) == 1
        result = Vector{Float64}(undef, length(first(variable.axes)))

        for t in variable.axes[1]
            result[t] = JuMP.value(variable[t])
        end

        return DataFrames.DataFrame(var = result)

    elseif length(axes(variable)) == 2

        result = Array{Float64, length(variable.axes)}(
            undef,
            length(variable.axes[2]),
            length(variable.axes[1]),
        )
        names = Array{Symbol, 1}(undef, length(variable.axes[1]))

        for t in variable.axes[2], (ix, name) in enumerate(variable.axes[1])
            result[t, ix] = JuMP.value(variable[name, t])
            names[ix] = Symbol(name)
        end

        return DataFrames.DataFrame(result, names)

    elseif length(axes(variable)) == 3
        extra_dims = sum(length(axes(variable)[2:(end - 1)]))
        extra_vars = [Symbol("S$(s)") for s in 1:extra_dims]
        result_df = DataFrames.DataFrame()
        names = vcat(extra_vars, Symbol.(axes(variable)[1]))

        for i in variable.axes[2]
            third_dim = collect(fill(i, size(variable)[end]))
            result = Array{Float64, 2}(
                undef,
                length(last(variable.axes)),
                length(first(variable.axes)),
            )
            for t in last(variable.axes), (ix, name) in enumerate(first(variable.axes))
                result[t, ix] = JuMP.value(variable[name, i, t])
            end
            res = DataFrames.DataFrame(hcat(third_dim, result))
            result_df = vcat(result_df, res)
        end

        return DataFrames.names!(result_df, names)

    else
        error("Dimension Number $(length(axes(variable))) not Supported")
    end

end

function result_dataframe_duals(constraint::JuMP.Containers.DenseAxisArray)
    if length(axes(constraint)) == 1
        result = Vector{Float64}(undef, length(first(constraint.axes)))
        for t in constraint.axes[1]
            try
                result[t] = JuMP.dual(constraint[t])
            catch
                result[t] = NaN
            end
        end
        return DataFrames.DataFrame(var = result)
    elseif length(axes(constraint)) == 2
        result = Array{Float64, length(constraint.axes)}(
            undef,
            length(constraint.axes[2]),
            length(constraint.axes[1]),
        )
        names = Array{Symbol, 1}(undef, length(constraint.axes[1]))
        for t in constraint.axes[2], (ix, name) in enumerate(constraint.axes[1])
            try
                result[t, ix] = JuMP.dual(constraint[name, t])
            catch
                result[t, ix] = NaN
            end
            names[ix] = Symbol(name)
        end
        return DataFrames.DataFrame(result, names)
    else
        error("Dimension Number $(length(axes(constraint))) not Supported")
    end
end
