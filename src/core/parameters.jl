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

struct ActivePowerTimeSeriesParameter <: TimeSeriesParameter
    name::String
end

struct ReactivePowerTimeSeriesParameter <: TimeSeriesParameter
    name::String
end

struct RequirementTimeSeriesParameter <: TimeSeriesParameter
    name::String
end

struct EnergyTargetTimeSeriesParameter <: TimeSeriesParameter
    name::String
end

struct EnergyBudgetTimeSeriesParameter <: TimeSeriesParameter
    name::String
end

struct InflowTimeSeriesParameter <: TimeSeriesParameter
    name::String
end

struct OutflowTimeSeriesParameter <: TimeSeriesParameter
    name::String
end

get_name(key::TimeSeriesParameter) = key.name

abstract type VariableValueParameter <: RightHandSideParameter end

struct BinaryValueParameter <: VariableValueParameter end
struct UpperBoundValueParameter <: VariableValueParameter end

abstract type AuxVariableValueParameter <: RightHandSideParameter end

struct EnergyTargetParameter <: AuxVariableValueParameter end
