struct ParameterKey{T <: ParameterType, U <: PSY.Component} <: OptimizationContainerKey
    meta::String
end

function ParameterKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: VariableType, U <: PSY.Component}
    check_meta_chars(meta)
    return ParameterKey{T, U}(meta)
end

function ParameterKey(::Type{T}) where {T <: VariableType}
    return ParameterKey(T, PSY.Component, CONTAINER_KEY_EMPTY_META)
end

function ParameterKey(::Type{T}, meta::String) where {T <: VariableType}
    return ParameterKey(T, PSY.Component, meta)
end

get_entry_type(::ParameterKey{T, U}) where {T <: VariableType, U <: PSY.Component} = T
get_component_type(::ParameterKey{T, U}) where {T <: VariableType, U <: PSY.Component} = U

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
abstract type RightHandSideParameter end
abstract type ObjectiveFunctionParameter end

abstract type TimeSeriesParameter <: RightHandSideParameter end

struct ActivePowerTimeSeries <: TimeSeriesParameter end
struct ServiceRequirementTimeSeries <: TimeSeriesParameter end

abstract type VariableValueParameter <: RightHandSideParameter end

struct BinaryValueParameter <: VariableValueParameter end
struct UpperBoundValueParameter <: VariableValueParameter end

abstract type AuxVariableValueParameter <: RightHandSideParameter end
