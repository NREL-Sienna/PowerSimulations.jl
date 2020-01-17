"""Reference for parameters update when present"""
struct UpdateRef{T}
    access_ref::Union{Symbol,String}
end

function UpdateRef{T}(name::AbstractString, ::Type{U}) where {T, U <: PSY.Device}
    return UpdateRef{T}(_encode_for_jump(name, U))
end

const DRDA = Dict{UpdateRef, JuMP.Containers.DenseAxisArray}
