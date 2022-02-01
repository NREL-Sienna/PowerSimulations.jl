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
    value::JuMP.Containers.DenseAxisArray{Dict{Symbol, Any}}
    units::Dates.TimePeriod
    ref::UpdateRef

    function TimeStatusChange(
        device_type::Type{<:PSY.Device},
        value::JuMP.Containers.DenseAxisArray{Dict{Symbol, Any}},
        ref::UpdateRef,
        units::Dates.TimePeriod,
    )
        units = IS.time_period_conversion(units)
        new(device_type, value, units, ref)
    end
end

function TimeStatusChange(::Type{T}, name::AbstractString, units::Dates.TimePeriod) where {T <: PSY.Device}
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Any}}(undef, 1)
    return TimeStatusChange(T, value_array, UpdateRef{JuMP.VariableRef}(T, name), units)
end

mutable struct StoredEnergy <: AbstractCache
    device_type::Type{<:PSY.Device}
    value::JuMP.Containers.DenseAxisArray{Float64}
    ref::UpdateRef
end

function StoredEnergy(::Type{T}, name::AbstractString) where {T <: PSY.Device}
    value_array = JuMP.Containers.DenseAxisArray{Float64}(undef, 1)
    return StoredEnergy(T, value_array, UpdateRef{JuMP.VariableRef}(T, name))
end

cache_value(cache::AbstractCache, key) = cache.value[key]
