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
    bus_number::Int
    multiplier::Float64
    timeseries::Vector{Float64}
    range::Union{Nothing, DeviceRange}
    function DeviceTimeSeries(name, bus_number, multiplier, timeseries, range)
        @assert isnothing(range) || name == range.name
        return new(name, bus_number, multiplier, timeseries, range)
    end
end

function DeviceTimeSeries(
    device::PSY.Device,
    multiplier_function::Function,
    ts_vector::Vector{Float64},
    get_constraint_values::Union{Function, Nothing} = nothing,
)
    name = PSY.get_name(device)
    bus_number = PSY.get_number(PSY.get_bus(device))
    multiplier = multiplier_function(device)
    if isnothing(get_constraint_values)
        range_data = nothing
    else
        range_data = DeviceRange(name, get_constraint_values(device))
    end
    return DeviceTimeSeries(name, bus_number, multiplier, ts_vector, range_data)
end
