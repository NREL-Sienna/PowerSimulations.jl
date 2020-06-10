abstract type AbstractRangeConstraintInfo end

""" Data Container to construct range constraints"""
struct DeviceRangeConstraintInfo <: AbstractRangeConstraintInfo
    name::String
    limits::MinMax
    additional_terms_ub::Vector{Symbol}
    additional_terms_lb::Vector{Symbol}
end

function DeviceRangeConstraintInfo(name::String, limits::MinMax)
    return DeviceRangeConstraintInfo(name, limits, Vector{Symbol}(), Vector{Symbol}())
end

function DeviceRangeConstraintInfo(name::String)
    return DeviceRangeConstraintInfo(
        name,
        (min = -Inf, max = Inf),
        Vector{Symbol}(),
        Vector{Symbol}(),
    )
end

get_name(d::DeviceRangeConstraintInfo) = d.name

struct DeviceTimeSeriesConstraintInfo
    bus_number::Int
    multiplier::Float64
    timeseries::Vector{Float64}
    range::DeviceRangeConstraintInfo
    function DeviceTimeSeriesConstraintInfo(
        bus_number,
        multiplier,
        timeseries,
        range_constraint_info,
    )
        return new(bus_number, multiplier, timeseries, range_constraint_info)
    end
end

get_name(d::DeviceTimeSeriesConstraintInfo) = d.range.name
get_limits(d::DeviceTimeSeriesConstraintInfo) = d.range.limits

function DeviceTimeSeriesConstraintInfo(
    device::PSY.Device,
    multiplier_function::Function,
    ts_vector::Vector{Float64},
    get_constraint_values::Union{Function, Nothing} = nothing,
)
    name = PSY.get_name(device)
    bus_number = PSY.get_number(PSY.get_bus(device))
    multiplier = multiplier_function(device)
    if isnothing(get_constraint_values)
        range_constraint_info = DeviceRangeConstraintInfo(name)
    else
        range_constraint_info =
            DeviceRangeConstraintInfo(name, get_constraint_values(device))
    end
    return DeviceTimeSeriesConstraintInfo(
        bus_number,
        multiplier,
        ts_vector,
        range_constraint_info,
    )
end
