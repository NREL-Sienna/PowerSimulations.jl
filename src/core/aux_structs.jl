"""Reference for parameters update when present"""
struct UpdateRef{T}
    access_ref::Union{Symbol, String}
    tag::Union{Nothing, String}
end

UpdateRef{T}(ar::Union{Symbol, String}) where T = UpdateRef{T}(ar, nothing)

const DRDA = Dict{UpdateRef, JuMP.Containers.DenseAxisArray}
