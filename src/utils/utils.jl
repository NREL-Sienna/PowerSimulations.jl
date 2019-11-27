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
