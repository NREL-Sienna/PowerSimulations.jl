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

abstract type ParameterAttributes end

struct NoAttributes end

struct TimeSeriesAttributes{T <: PSY.TimeSeriesData} <: ParameterAttributes
    name::String
end

get_time_series_type(::TimeSeriesAttributes{T}) where {T <: PSY.TimeSeriesData} = T
get_name(attr::TimeSeriesAttributes) = attr.name

struct ParameterContainer
    attributes::ParameterAttributes
    parameter_array::JuMP.Containers.DenseAxisArray
    multiplier_array::JuMP.Containers.DenseAxisArray
end

function ParameterContainer(parameter_array, multiplier_array)
    return ParamterContainer(NoAttributes(), parameter_array, multiplier_array)
end

get_parameter_array(c::ParameterContainer) = c.parameter_array
get_multiplier_array(c::ParameterContainer) = c.multiplier_array
Base.length(c::ParameterContainer) = length(c.parameter_array)
Base.size(c::ParameterContainer) = size(c.parameter_array)

function _set_parameter!(
    array::AbstractArray{Float64},
    ::JuMP.Model,
    value::Float64,
    ixs::Tuple,
)
    array[ixs...] = value
    return
end

function _set_parameter!(
    array::AbstractArray{PJ.ParameterRef},
    model::JuMP.Model,
    value::Float64,
    ixs::Tuple,
)
    array[ixs...] = add_jump_parameter(model, value)
    return
end

function set_parameter!(
    container::ParameterContainer,
    jump_model::JuMP.Model,
    parameter::Float64,
    multiplier::Float64,
    ixs...,
)
    get_multiplier_array(container)[ixs...] = multiplier
    param_array = get_parameter_array(container)
    _set_parameter!(param_array, jump_model, parameter, ixs)
end

"""
Parameters implemented through ParameterJuMP
"""
abstract type RightHandSideParameter <: ParameterType end
abstract type ObjectiveFunctionParameter <: ParameterType end

abstract type TimeSeriesParameter <: RightHandSideParameter end

struct ActivePowerTimeSeriesParameter <: TimeSeriesParameter end

struct ReactivePowerTimeSeriesParameter <: TimeSeriesParameter end

struct RequirementTimeSeriesParameter <: TimeSeriesParameter end

struct EnergyTargetTimeSeriesParameter <: TimeSeriesParameter end

struct EnergyBudgetTimeSeriesParameter <: TimeSeriesParameter end

struct InflowTimeSeriesParameter <: TimeSeriesParameter end

struct OutflowTimeSeriesParameter <: TimeSeriesParameter end

abstract type VariableValueParameter <: RightHandSideParameter end

struct BinaryValueParameter <: VariableValueParameter end
struct UpperBoundValueParameter <: VariableValueParameter end

abstract type AuxVariableValueParameter <: RightHandSideParameter end

struct EnergyTargetParameter <: AuxVariableValueParameter end
