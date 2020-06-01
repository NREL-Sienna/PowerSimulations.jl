abstract type RangeConstraintsData end
abstract type RampConstraintsData end

""" Data Container to construct range constraints"""
struct DeviceRange <: RangeConstraintsData
    name::String
    limits::MinMax
    additional_terms_ub::Vector{Symbol}
    additional_terms_lb::Vector{Symbol}
end

function DeviceRange(name::String, limits::MinMax)
    return DeviceRange(name, limits, Vector{Symbol}(), Vector{Symbol}())
end

function DeviceRange(name::String)
    return DeviceRange(name, (min = -Inf, max = Inf), Vector{Symbol}(), Vector{Symbol}())
end

struct DeviceTimeSeries <: RangeConstraintsData
    name::String
    bus_number::Int
    multiplier::Float64
    timeseries::Vector{Float64}
    range::DeviceRange
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
        range_data = DeviceRange(name)
    else
        range_data = DeviceRange(name, get_constraint_values(device))
    end
    return DeviceTimeSeries(name, bus_number, multiplier, ts_vector, range_data)
end

struct DeviceRangePGLIB <: PSI.RangeConstraintsData
    name::String
    limits::PSY.Min_Max
    ramplimits::NamedTuple{(:startup, :shutdown), Tuple{Float64, Float64}}
    additional_terms_ub::Vector{Symbol}# [:R1, :R2]
    additional_terms_lb::Vector{Symbol}
end

function DeviceRangePGLIB(
    name::String,
    limits::PSY.Min_Max,
    ramplimits::NamedTuple{(:startup, :shutdown), Tuple{Float64, Float64}},
)
    return DeviceRangePGLIB(name, limits, ramplimits, Vector{Symbol}(), Vector{Symbol}())
end

function DeviceRangePGLIB(name::String)
    return DeviceRangePGLIB(
        name,
        (min = -Inf, max = Inf),
        (startup = Inf, shutdown = Inf),
        Vector{Symbol}(),
        Vector{Symbol}(),
    )
end

struct DeviceRampPGLIB <: PSI.RampConstraintsData
    name::String
    limits::PSI.MinMax
    ramplimits::PSI.UpDown
    additional_terms_ub::Vector{Symbol}
    additional_terms_lb::Vector{Symbol}
end

function DeviceRampPGLIB(name::String, limits::PSY.Min_Max, ramplimits::PSI.UpDown)
    return DeviceRangePGLIB(name, limits, ramplimits, Vector{Symbol}(), Vector{Symbol}())
end

function DeviceRampPGLIB(name::String)
    return DeviceRangePGLIB(
        name,
        (min = -Inf, max = Inf),
        (up = Inf, down = Inf),
        Vector{Symbol}(),
        Vector{Symbol}(),
    )
end

struct DeviceStartUp
    name::String
    time_limits::StartUp
    startup_types::Int
end

struct DeviceStartTypes
    name::String
    startup_types::Int
end
