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
