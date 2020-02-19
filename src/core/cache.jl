struct CacheKey{C <: AbstractCache, D <: PSY.Device}
    cache_type::Type{C}
    device_type::Type{D}
end

function CacheKey(cache::C) where {C <: AbstractCache}
    return CacheKey(C, cache.device_type)
end
# The current implementation will require all custom caches to have the same data template
"""
Tracks the last time status of a device changed in a simulation
"""
mutable struct TimeStatusChange <: AbstractCache
    device_type::Type{<:PSY.Device}
    value::JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}
    ref::UpdateRef
end

function TimeStatusChange(::Type{T}, name::AbstractString) where {T <: PSY.Device}
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}(undef, 1)
    return TimeStatusChange(T, value_array, UpdateRef{JuMP.VariableRef}(T, name))
end

cache_value(cache::AbstractCache, key) = cache.value[key]
