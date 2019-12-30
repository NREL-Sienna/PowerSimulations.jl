""" Data Container to construct range constraints"""
struct DeviceRange
    name::String
    limits::MinMax
    additional_terms_ub::Vector{Symbol}
    additional_terms_lb::Vector{Symbol}
end

function DeviceRange(name::String, limits::MinMax)
    return DeviceRange(name, limits, Vector{Symbol}(), Vector{Symbol}())
end

struct DeviceTimeSeries
    name::String
    bus_number::Int64
    multiplier::Float64
    timeseries::Vector{Float64}
    range::Union{Nothing,DeviceRange}
end
