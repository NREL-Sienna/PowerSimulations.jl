"""Reference for parameters update when present"""
struct UpdateRef{T}
    access_ref::Union{Symbol,String}
end

const DRDA = Dict{UpdateRef, JuMP.Containers.DenseAxisArray}
