"""Reference for parameters update when present"""
struct UpdateRef{T}
    access_ref::Symbol
end

const DRDA = Dict{UpdateRef, JuMP.Containers.DenseAxisArray}
