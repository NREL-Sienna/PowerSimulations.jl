"""Reference for parameters update when present"""
struct UpdateRef{T}
    access_ref::Symbol
end

const DSDA = Dict{Symbol, JuMP.Containers.DenseAxisArray}
const DRDA = Dict{UpdateRef, JuMP.Containers.DenseAxisArray}
