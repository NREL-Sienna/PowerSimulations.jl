""" Data Container to construct range constraints"""
struct DeviceRange
    limits::MinMax
    additional_terms_ub::Vector{Symbol}
    additional_terms_lb::Vector{Symbol}
end

struct DeviceTimeSeries
    bus_number::Int64
    multiplier::Float64
    timeseries::Vector{Float64}
end
