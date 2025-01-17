abstract type AbstractEventCondition end
struct ContinuousCondition <: AbstractEventCondition end

struct PresetTimeCondition <: AbstractEventCondition
    time_stamps::Vector{Dates.DateTime}
end

get_time_stamps(c::PresetTimeCondition) = c.time_stamps

struct StateVariableValueCondition <: AbstractEventCondition
    variable_type::Type{<:VariableType}
    device_type::Type{<:PSY.Device}
    device_name::String
    value::Float64
end

get_variable_type(c::StateVariableValueCondition) = c.variable_type
get_device_type(c::StateVariableValueCondition) = c.device_type
get_device_name(c::StateVariableValueCondition) = c.device_name
get_value(c::StateVariableValueCondition) = c.value

struct DiscreteEventCondition <: AbstractEventCondition
    condition_function::Function
end

get_condition_function(c::DiscreteEventCondition) = c.condition_function

mutable struct EventModel{D <: PSY.Contingency, B <: AbstractEventCondition}
    condition::B
    attribute_device_map::Dict{Symbol, Dict{Base.UUID, Dict{DataType, Set{String}}}}
    attributes::Dict{String, Any}

    function EventModel(
        ::Type{D},
        condition::B;
        attributes = Dict{String, Any}(),
    ) where {D <: PSY.Contingency, B <: AbstractEventCondition}
        new{D, B}(
            condition,
            Dict{Symbol, Dict{Base.UUID, Dict{DataType, Set{String}}}}(),
            attributes,
        )
    end
end

get_event_type(
    ::EventModel{D, B},
) where {D <: PSY.Contingency, B <: AbstractEventCondition} = D

get_event_condition(
    e::EventModel{D, B},
) where {D <: PSY.Contingency, B <: AbstractEventCondition} = e.condition

get_attribute_device_map(e::EventModel) = e.attribute_device_map
