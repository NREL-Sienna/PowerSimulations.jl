abstract type AbstractConstraintInfo end
abstract type AbstractRangeConstraintInfo <: AbstractConstraintInfo end
abstract type AbstractRampConstraintInfo <: AbstractConstraintInfo end
abstract type AbstractStartConstraintInfo <: AbstractConstraintInfo end

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
get_timeseries(d::DeviceTimeSeriesConstraintInfo) = d.timeseries

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

struct DeviceMultiStartRangeConstraintsInfo <: AbstractRangeConstraintInfo
    name::String
    limits::PSY.Min_Max
    lag_ramp_limits::NamedTuple{(:startup, :shutdown), Tuple{Float64, Float64}}
    additional_terms_ub::Vector{Symbol}# [:R1, :R2]
    additional_terms_lb::Vector{Symbol}
end

function DeviceMultiStartRangeConstraintsInfo(
    name::String,
    limits::PSY.Min_Max,
    lag_ramp_limits::NamedTuple{(:startup, :shutdown), Tuple{Float64, Float64}},
)
    return DeviceMultiStartRangeConstraintsInfo(
        name,
        limits,
        lag_ramp_limits,
        Vector{Symbol}(),
        Vector{Symbol}(),
    )
end

function DeviceMultiStartRangeConstraintsInfo(name::String)
    return DeviceMultiStartRangeConstraintsInfo(
        name,
        (min = -Inf, max = Inf),
        (startup = Inf, shutdown = Inf),
        Vector{Symbol}(),
        Vector{Symbol}(),
    )
end

struct DeviceRampConstraintInfo <: AbstractRampConstraintInfo
    name::String
    limits::PSI.MinMax
    ramplimits::PSI.UpDown
    additional_terms_ub::Vector{Symbol}
    additional_terms_lb::Vector{Symbol}
end

function DeviceRampConstraintInfo(name::String, limits::PSY.Min_Max, ramplimits::PSI.UpDown)
    return DeviceRampConstraintInfo(
        name,
        limits,
        ramplimits,
        Vector{Symbol}(),
        Vector{Symbol}(),
    )
end

function DeviceRampConstraintInfo(name::String)
    return DeviceRampConstraintInfo(
        name,
        (min = -Inf, max = Inf),
        (up = Inf, down = Inf),
        Vector{Symbol}(),
        Vector{Symbol}(),
    )
end

struct DeviceStartUpConstraintInfo <: AbstractStartConstraintInfo
    name::String
    time_limits::StartUp
    startup_types::Int
end

struct DeviceStartTypesConstraintInfo <: AbstractStartConstraintInfo
    name::String
    startup_types::Int
end
