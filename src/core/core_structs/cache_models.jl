abstract type AbstractCache end

"""
Tracks the last time status of a device changed in a simulation
"""
mutable struct TimeStatusChange <: AbstractCache
    value::Float64
    last_status::Float64
    ref::UpdateRef
end

function TimeStatusChange(parameter::Symbol)
    return TimeStatusChange(0.0, 999.0, UpdateRef{Parameter}(parameter))
end
