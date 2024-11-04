"""
Return a decoded JSON file.
"""
function read_json(filename::AbstractString)
    open(filename, "r") do io
        JSON3.read(io)
    end
end

"""
Return a DataFrame from a CSV file.
"""
function read_dataframe(filename::AbstractString)
    return CSV.read(filename, DataFrames.DataFrame)
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

function read_file_hashes(path)
    data = open(joinpath(path, IS.HASH_FILENAME), "r") do io
        JSON3.read(io)
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
        actual_hash = IS.compute_sha256(joinpath(path, filename))
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
