function to_json(data; indent=nothing)
    if isnothing(indent)
        return JSON3.write(data)
    end

    buf = IOBuffer()
    JSON3.pretty(buf, data, JSON3.AlignmentContext(indent=indent))
    return String(take!(buf))
end

function from_json(::Type{T}, data::AbstractString) where T
    JSON3.read(data, T)
end
