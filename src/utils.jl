"""
Return a decoded JSON file.
"""
function read_json(filename::AbstractString)
    open(filename, "r") do io
        JSON.parse(io)
    end
end

"""
Return a DataFrame from a CSV file.
"""
function read_dataframe(filename::AbstractString)
    open(filename, "r") do io
        DataFrames.DataFrame(CSV.File(io))
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
    data = Dict("files" => [])
    for file in files
        file_path = joinpath(path, file)
        file_info = Dict("filename" => file_path, "hash" => compute_sha256(file_path))
        push!(data["files"], file_info)
    end

    open(joinpath(path, HASH_FILENAME), "w") do io
        write(io, JSON.json(data))
    end
end

function compute_file_hash(path::String, file::String)
    return compute_file_hash(path, [file])
end

function read_file_hashes(path)
    data = open(joinpath(path, HASH_FILENAME), "r") do io
        JSON.parse(io)
    end

    return data["files"]
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

# writing a dictionary of dataframes to files and appending the time

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

#Given the changes in syntax in ParameterJuMP and the new format to create anonymous parameters
function add_parameter(model::JuMP.Model, val::Number)
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

function _jump_value(input::PJ.ParameterRef)
    return PJ.value(input)
end

function _jump_value(input::JuMP.ConstraintRef)
    return JuMP.dual(input)
end

"""
Creates a DataFrame from a JuMP DenseAxisArray or SparseAxisArray.

# Arguments
- `input_array`: JuMP DenseAxisArray or SparseAxisArray to convert
- `columns::Vector{Symbol}`: Required when there is only one axis which is data. Ignored if
  `input_array` includes an axis for device names.
"""
function axis_array_to_dataframe(
    input_array::JuMP.Containers.DenseAxisArray{Float64},
    columns = nothing,
)
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

function axis_array_to_dataframe(
    input_array::JuMP.Containers.DenseAxisArray{},
    columns = nothing,
)
    if length(axes(input_array)) == 1
        result = Vector{Float64}(undef, length(first(input_array.axes)))
        for t in input_array.axes[1]
            result[t] = _jump_value(input_array[t])
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

function axis_array_to_dataframe(
    input_array::JuMP.Containers.SparseAxisArray,
    columns = nothing,
)
    column_names = unique([(k[1], k[2]) for k in keys(input_array.data)])
    array_values = Vector{Vector{Float64}}()
    final_column_names = Vector{Symbol}()
    for (ix, col) in enumerate(column_names)
        res = values(
            filter(v -> (first(v)[[1, 2]] == col) && (last(v) != 0), input_array.data),
        )
        if !isempty(res)
            push!(array_values, PSI._jump_value.(res))
            push!(final_column_names, Symbol(col...))
        end
    end
    return DataFrames.DataFrame(array_values, (final_column_names))
end

function axis_array_to_dataframe(input_array::Matrix{Float64}, columns)
    return DataFrames.DataFrame(input_array, columns)
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
    columns = unique([(k[1], k[2]) for k in keys(array.data)])
    # PERF: can we determine the 2-d array size?
    tmp_data = Dict{Any, Vector{Float64}}()
    final_column_names = Vector{Symbol}()
    for (ix, col) in enumerate(columns)
        res = values(filter(v -> (first(v)[[1, 2]] == col) && (last(v) != 0), array.data))
        if !isempty(res)
            tmp_data[Symbol(col...)] = PSI._jump_value.(res)
            push!(final_column_names, Symbol(col...))
        end
    end

    data = Array{Float64, 2}(
        undef,
        length(first(values(tmp_data))),
        length(final_column_names),
    )
    for (i, column) in enumerate(final_column_names)
        data[:, i] = tmp_data[column]
    end

    return data
end

to_array(array::Array) = array

# this ensures that the time_stamp is not double shortened
function find_var_length(es::Dict, e_list::Array)
    return size(es[Symbol(splitext(e_list[1])[1])], 1)
end

""" Returns the correct container spec for the selected type of JuMP Model"""
function container_spec(::Type{T}, axs...) where {T <: Any}
    return JuMP.Containers.DenseAxisArray{T}(undef, axs...)
end

""" Returns the correct container spec for the selected type of JuMP Model"""
function sparse_container_spec(::Type{T}, axs...) where {T <: Any}
    indexes = Base.Iterators.product(axs...)
    contents = Dict{eltype(indexes), Any}(indexes .=> 0)
    return JuMP.Containers.SparseAxisArray(contents)
end

function middle_rename(original::Symbol, split_char::String, addition::String)
    parts = split(String(original), split_char)
    parts[1] = parts[1] * "_" * addition
    return Symbol(join(parts, split_char))
end

"Replaces the string in `char` with the string`replacement`"
function replace_chars(s::String, char::String, replacement::String)
    return replace(s, Regex("[$char]") => replacement)
end

convert_for_path(x::Dates.DateTime) = replace(string(x), ":" => "-")

"Removes the string `char` from the original string"
function remove_chars(s::String, char::String)
    return replace_chars(s::String, char::String, "")
end

function is_hybrid_sub_component(x::T) where {T <: PSY.Component}
    ext = PSY.get_ext(x)
    if haskey(ext, "is_hybrid_subcomponent") && ext["is_hybrid_subcomponent"]
        return true
    else
        return false
    end
end

function get_available_components(::Type{T}, sys::PSY.System) where {T <: PSY.Component}
    return PSY.get_components(
        T,
        sys,
        x -> PSY.get_available(x) & !is_hybrid_sub_component(x),
    )
end

function get_available_components(
    ::Type{PSY.RegulationDevice{T}},
    sys::PSY.System,
) where {T <: PSY.Component}
    return PSY.get_components(
        PSY.RegulationDevice{T},
        sys,
        x -> (PSY.get_available(x) && PSY.has_service(x, PSY.AGC)),
    )
end

"""
    check_file_integrity(path::String)

Checks the hash value for each file made with the file is written with the new hash_value to verify the file hasn't been tampered with since written

# Arguments
- `path::String`: this is the folder path that contains the results and the check.sha256 file
"""
function check_file_integrity(path::String)
    matched = true
    for file_info in read_file_hashes(path)
        filename = file_info["filename"]
        @info "checking integrity of $filename"
        expected_hash = file_info["hash"]
        actual_hash = compute_sha256(filename)
        if expected_hash != actual_hash
            @error "hash mismatch for file" filename expected_hash actual_hash
            matched = false
        end
    end

    if !matched
        throw(
            IS.HashMismatchError(
                "The hash value in the written files does not match the read files, results may have been tampered.",
            ),
        )
    end
end

to_namedtuple(val) = (; (x => getfield(val, x) for x in fieldnames(typeof(val)))...)

make_system_filename(sys::PSY.System) = "system-$(IS.get_uuid(sys)).json"
make_system_filename(sys_uuid::Base.UUID) = "system-$(sys_uuid).json"

function encode_symbol(::Type{T}, name1::AbstractString, name2::AbstractString) where {T}
    return Symbol(join((name1, name2, IS.strip_module_name(T)), PSI_NAME_DELIMITER))
end

function encode_symbol(
    ::Type{T},
    name1::AbstractString,
    name2::AbstractString,
) where {T <: PSY.Reserve}
    T_ = replace(IS.strip_module_name(T), "{" => "_")
    T_ = replace(T_, "}" => "")
    return Symbol(join((name1, name2, T_), PSI_NAME_DELIMITER))
end

function encode_symbol(::Type{T}, name1::Symbol, name2::Symbol) where {T}
    return encode_symbol(IS.strip_module_name(T), string(name1), string(name2))
end

function encode_symbol(::Type{T}, name::AbstractString) where {T}
    return Symbol(join((name, IS.strip_module_name(T)), PSI_NAME_DELIMITER))
end

function encode_symbol(::Type{T}, name::AbstractString) where {T <: PSY.Reserve}
    T_ = replace(IS.strip_module_name(T), "{" => "_")
    T_ = replace(T_, "}" => "")
    return Symbol(join((name, T_), PSI_NAME_DELIMITER))
end

function encode_symbol(::Type{T}, name::Symbol) where {T}
    return encode_symbol(T, string(name))
end

function encode_symbol(name::AbstractString)
    return Symbol(name)
end

function encode_symbol(name1::AbstractString, name2::AbstractString)
    return Symbol(join((name1, name2), PSI_NAME_DELIMITER))
end

function encode_symbol(name::Symbol)
    return name
end

function decode_symbol(name::Symbol)
    return split(String(name), PSI_NAME_DELIMITER)
end
