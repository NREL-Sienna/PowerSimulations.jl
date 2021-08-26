struct ParameterKey{T <: ParameterType, U <: PSY.Component} <: OptimizationContainerKey
    meta::String
end

function ParameterKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType, U <: PSY.Component}
    check_meta_chars(meta)
    return ParameterKey{T, U}(meta)
end

function ParameterKey(::Type{T}) where {T <: ParameterType}
    return ParameterKey(T, PSY.Component, CONTAINER_KEY_EMPTY_META)
end

function ParameterKey(::Type{T}, meta::String) where {T <: ParameterType}
    return ParameterKey(T, PSY.Component, meta)
end

get_entry_type(::ParameterKey{T, U}) where {T <: ParameterType, U <: PSY.Component} = T
get_component_type(::ParameterKey{T, U}) where {T <: ParameterType, U <: PSY.Component} = U

struct ParameterContainer
    parameter_array::JuMP.Containers.DenseAxisArray
    multiplier_array::JuMP.Containers.DenseAxisArray
end

get_parameter_array(c::ParameterContainer) = c.parameter_array
get_multiplier_array(c::ParameterContainer) = c.multiplier_array
Base.length(c::ParameterContainer) = length(c.parameter_array)
Base.size(c::ParameterContainer) = size(c.parameter_array)

"""
Parameters implemented through ParameterJuMP
"""
abstract type RightHandSideParameter <: ParameterType end
abstract type ObjectiveFunctionParameter <: ParameterType end

abstract type TimeSeriesParameter <: RightHandSideParameter end

struct TimeSeriesAttributes{T <: PSY.TimeSeriesData}
    name::String
end

get_time_series_type(::TimeSeriesAttributes{T}) where {T <: PSY.TimeSeriesData} = T
get_name(attr::TimeSeriesAttributes) = attr.name

function get_time_series_type(param::TimeSeriesParameter)
    return get_time_series_type(param.common)
end

struct ActivePowerTimeSeriesParameter <: TimeSeriesParameter
    attributes::TimeSeriesAttributes
end

function ActivePowerTimeSeriesParameter(::Type{T}, name) where {T <: PSY.TimeSeriesData}
    return ActivePowerTimeSeriesParameter(TimeSeriesAttributes{T}(name))
end

struct ReactivePowerTimeSeriesParameter <: TimeSeriesParameter
    attributes::TimeSeriesAttributes
end

function ReactivePowerTimeSeriesParameter(::Type{T}, name) where {T <: PSY.TimeSeriesData}
    return RectivePowerTimeSeriesParameter(TimeSeriesAttributes{T}(name))
end

struct RequirementTimeSeriesParameter <: TimeSeriesParameter
    attributes::TimeSeriesAttributes
end

function RequirementTimeSeriesParameter(::Type{T}, name) where {T <: PSY.TimeSeriesData}
    return RequirementTimeSeriesParameter(TimeSeriesAttributes{T}(name))
end

struct EnergyTargetTimeSeriesParameter <: TimeSeriesParameter
    attributes::TimeSeriesAttributes
end

function EnergyTargetTimeSeriesParameter(::Type{T}, name) where {T <: PSY.TimeSeriesData}
    return EnergyTargetTimeSeriesParameter(TimeSeriesAttributes{T}(name))
end

struct EnergyBudgetTimeSeriesParameter <: TimeSeriesParameter
    attributes::TimeSeriesAttributes
end

function EnergyBudgetTimeSeriesParameter(::Type{T}, name) where {T <: PSY.TimeSeriesData}
    EnergyBudgetTimeSeriesParameter(TimeSeriesAttributes{T}(name))
end

struct InflowTimeSeriesParameter <: TimeSeriesParameter
    attributes::TimeSeriesAttributes
end

function InflowTimeSeriesParameter(::Type{T}, name) where {T <: PSY.TimeSeriesData}
    InflowTimeSeriesParameter(TimeSeriesAttributes{T}(name))
end

struct OutflowTimeSeriesParameter <: TimeSeriesParameter
    attributes::TimeSeriesAttributes
end

function OutflowTimeSeriesParameter(::Type{T}, name) where {T <: PSY.TimeSeriesData}
    OutflowTimeSeriesParameter(TimeSeriesAttributes{T}(name))
end

get_name(key::TimeSeriesParameter) = key.attributes.name

abstract type VariableValueParameter <: RightHandSideParameter end

struct BinaryValueParameter <: VariableValueParameter end
struct UpperBoundValueParameter <: VariableValueParameter end

abstract type AuxVariableValueParameter <: RightHandSideParameter end

struct EnergyTargetParameter <: AuxVariableValueParameter end
