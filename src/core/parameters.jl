struct ParameterKey{T <: ParameterType, U <: PSY.Component} <: OptimizationContainerKey
    meta::String
end

function ParameterKey(
    ::Type{T},
    ::Type{U},
    meta=CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType, U <: PSY.Component}
    if isabstracttype(U)
        error("Type $U can't be abstract")
    end
    check_meta_chars(meta)
    return ParameterKey{T, U}(meta)
end

function ParameterKey(
    ::Type{T},
    meta::String=CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType}
    return ParameterKey(T, PSY.Component, meta)
end

get_entry_type(::ParameterKey{T, U}) where {T <: ParameterType, U <: PSY.Component} = T
get_component_type(::ParameterKey{T, U}) where {T <: ParameterType, U <: PSY.Component} = U

abstract type ParameterAttributes end

struct NoAttributes end

struct TimeSeriesAttributes{T <: PSY.TimeSeriesData} <: ParameterAttributes
    name::String
    multiplier_id::Base.RefValue{Int}
end

function TimeSeriesAttributes(
    ::Type{T},
    name::String,
    multiplier_id::Int=1,
) where {T <: PSY.TimeSeriesData}
    return TimeSeriesAttributes{T}(name, Base.RefValue{Int}(multiplier_id))
end

get_time_series_type(::TimeSeriesAttributes{T}) where {T <: PSY.TimeSeriesData} = T
get_time_series_name(attr::TimeSeriesAttributes) = attr.name
get_time_series_multiplier_id(attr::TimeSeriesAttributes) = attr.multiplier_id[]
function set_time_series_multiplier_id!(attr::TimeSeriesAttributes, val::Int)
    attr.multiplier_id[] = val
    return
end

struct VariableValueAttributes{T <: OptimizationContainerKey} <: ParameterAttributes
    attribute_key::T
end

get_attribute_key(attr::VariableValueAttributes) = attr.attribute_key

struct CostFunctionAttributes{T} <: ParameterAttributes
    variable_type::Type
    sos_status::SOSStatusVariable
    uses_compact_power::Bool
end

get_sos_status(attr::CostFunctionAttributes) = attr.sos_status
get_variable_type(attr::CostFunctionAttributes) = attr.variable_type
get_uses_compact_power(attr::CostFunctionAttributes) = attr.uses_compact_power

struct ParameterContainer
    attributes::ParameterAttributes
    parameter_array::AbstractArray
    multiplier_array::AbstractArray
end

function ParameterContainer(parameter_array, multiplier_array)
    return ParameterContainer(NoAttributes(), parameter_array, multiplier_array)
end

get_parameter_array(c::ParameterContainer) = c.parameter_array
get_multiplier_array(c::ParameterContainer) = c.multiplier_array
get_attributes(c::ParameterContainer) = c.attributes
Base.length(c::ParameterContainer) = length(c.parameter_array)
Base.size(c::ParameterContainer) = size(c.parameter_array)

function get_column_names(key::ParameterKey, c::ParameterContainer)
    return get_column_names(key, get_parameter_array(c))
end

function _set_parameter!(
    array::AbstractArray{Float64},
    ::JuMP.Model,
    value::Float64,
    ixs::Tuple,
)
    array[ixs...] = value
    return
end

function _set_parameter!(array::AbstractArray, ::JuMP.Model, value::Float64, ixs::Tuple)
    array[ixs...] = value
    return
end

function _set_parameter!(
    array::AbstractArray{Vector{NTuple{2, Float64}}},
    ::JuMP.Model,
    value::Vector{NTuple{2, Float64}},
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
    return
end

function set_parameter!(
    container::ParameterContainer,
    jump_model::JuMP.Model,
    parameter::Vector{NTuple{2, Float64}},
    multiplier::Float64,
    ixs...,
)
    get_multiplier_array(container)[ixs...] = multiplier
    param_array = get_parameter_array(container)
    _set_parameter!(param_array, jump_model, parameter, ixs)
    return
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

struct UpperBoundValueParameter <: VariableValueParameter end
struct LowerBoundValueParameter <: VariableValueParameter end
struct OnStatusParameter <: VariableValueParameter end
struct EnergyLimitParameter <: VariableValueParameter end
struct FixValueParameter <: VariableValueParameter end
struct EnergyTargetParameter <: VariableValueParameter end

struct CostFunctionParameter <: ObjectiveFunctionParameter end

abstract type AuxVariableValueParameter <: RightHandSideParameter end

should_write_resulting_value(::Type{<:ParameterType}) = false
should_write_resulting_value(::Type{<:RightHandSideParameter}) = true

convert_result_to_natural_units(::Type{<:ParameterType}) = false

convert_result_to_natural_units(::Type{ActivePowerTimeSeriesParameter}) = true
convert_result_to_natural_units(::Type{ReactivePowerTimeSeriesParameter}) = true
convert_result_to_natural_units(::Type{RequirementTimeSeriesParameter}) = true
convert_result_to_natural_units(::Type{EnergyTargetTimeSeriesParameter}) = true
convert_result_to_natural_units(::Type{EnergyBudgetTimeSeriesParameter}) = true
#convert_result_to_natural_units(::Type{InflowTimeSeriesParameter}) = true # TODO: is this pu?
#convert_result_to_natural_units(::Type{OutflowTimeSeriesParameter}) = true # TODO: is this pu?
convert_result_to_natural_units(::Type{UpperBoundValueParameter}) = true
convert_result_to_natural_units(::Type{LowerBoundValueParameter}) = true
convert_result_to_natural_units(::Type{EnergyLimitParameter}) = true
convert_result_to_natural_units(::Type{EnergyTargetParameter}) = true
