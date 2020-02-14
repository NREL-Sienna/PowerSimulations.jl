"""
Tracks the last time status of a device changed in a simulation
"""
mutable struct TimeStatusChange <: AbstractCache
    value::JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}
    ref::UpdateRef
end

function TimeStatusChange(::Type{T}, name::AbstractString) where {T <: PSY.Device}
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}(undef, 1)
    return TimeStatusChange(value_array, UpdateRef{PJ.ParameterRef}(T, name))
end

cache_value(cache::AbstractCache, key) = cache.value[key]
