"""Reference for parameters update when present"""
struct UpdateRef{T}
    access_ref::Union{Symbol,String}
end

struct CacheKey{C<:CacheQuantity}
    quantity::Type{C}
    ref::UpdateRef
end

const DRDA = Dict{UpdateRef, JuMP.Containers.DenseAxisArray}
