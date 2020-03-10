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
    if :duals in keys(kwargs)
        name = "dual_"
    elseif :params in keys(kwargs)
        name = "parameter_"
    else
        name = ""
    end
    if file_type == Feather || file_type == CSV
        for (k, v) in vars_results
            file_path = joinpath(save_path, "$name$k.$(lowercase("$file_type"))")
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

function write_optimizer_log(optimizer_log::Dict, save_path::AbstractString)
    JSON.write(joinpath(save_path, "optimizer_log.json"), JSON.json(optimizer_log))
end

function write_data(base_power::Float64, save_path::String)
    JSON.write(joinpath(save_path, "base_power.json"), JSON.json(base_power))
end

function _jump_value(input::JuMP.VariableRef)
    return JuMP.value(input)
end

function _jump_value(input::PJ.ParameterRef)
    return PJ.value(input)
end

function _jump_value(input::JuMP.ConstraintRef)
    return JuMP.dual(input)
end

function axis_array_to_dataframe(input_array::JuMP.Containers.DenseAxisArray{Float64})
    if length(axes(input_array)) == 1
        result = Vector{Float64}(undef, length(first(input_array.axes)))

        for t in input_array.axes[1]
            result[t] = input_array[t]
        end

        return DataFrames.DataFrame(var = result)

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
            res = DataFrames.DataFrame(hcat(third_dim, result))
            result_df = vcat(result_df, res)
        end

        return DataFrames.names!(result_df, names)

    else
        error("Dimension Number $(length(axes(input_array))) not Supported")
    end

end

function axis_array_to_dataframe(input_array::JuMP.Containers.DenseAxisArray{})
    if length(axes(input_array)) == 1
        result = Vector{Float64}(undef, length(first(input_array.axes)))

        for t in input_array.axes[1]
            result[t] = _jump_value(input_array[t])
        end

        return DataFrames.DataFrame(var = result)

    elseif length(axes(input_array)) == 2

        result = Array{Float64, length(input_array.axes)}(
            undef,
            length(input_array.axes[2]),
            length(input_array.axes[1]),
        )
        names = Array{Symbol, 1}(undef, length(input_array.axes[1]))

        for t in input_array.axes[2], (ix, name) in enumerate(input_array.axes[1])
            result[t, ix] = _jump_value(input_array[name, t])
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

                result[t, ix] = _jump_value(input_array[name, i, t])
            end
            res = DataFrames.DataFrame(hcat(third_dim, result))
            result_df = vcat(result_df, res)
        end

        return DataFrames.names!(result_df, names)

    else
        error("Dimension Number $(length(axes(input_array))) not Supported")
    end

end

# this ensures that the time_stamp is not double shortened
function find_var_length(es::Dict, e_list::Array)
    return size(es[Symbol(splitext(e_list[1])[1])], 1)
end

function shorten_time_stamp(time::DataFrames.DataFrame)
    time = time[1:(size(time, 1) - 1), :]
    return time
end

""" Returns the correct container spec for the selected type of JuMP Model"""
function container_spec(m::M, axs...) where {M <: JuMP.AbstractModel}
    return JuMP.Containers.DenseAxisArray{JuMP.variable_type(m)}(undef, axs...)
end

function middle_rename(original::Symbol, split_char::String, addition::String)
    parts = split(String(original), split_char)
    return Symbol(parts[1], "_", addition, PSI_NAME_DELIMITER, parts[2])
end

"Replaces the string in `char` with the string`replacement`"
function replace_chars(s::String, char::String, replacement::String)
    return replace(s, Regex("[$char]") => replacement)
end

"Removes the string `char` from the original string"
function remove_chars(s::String, char::String)
    return replace_chars(s::String, char::String, "")
end
