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
        # Don't put the path in the file so that we can move results directories.
        file_info = Dict("filename" => file, "hash" => compute_sha256(file_path))
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

# this ensures that the timestamp is not double shortened
function find_variable_length(es::Dict, e_list::Array)
    return size(es[Symbol(splitext(e_list[1])[1])], 1)
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
        actual_hash = compute_sha256(joinpath(path, filename))
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

convert_for_path(x::Dates.DateTime) = replace(string(x), ":" => "-")
