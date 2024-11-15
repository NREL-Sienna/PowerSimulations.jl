abstract type AbstractEventCondition end
struct ContinuousCondition <: AbstractEventCondition end

struct PresetTimeCondition <: AbstractEventCondition
    time_stamps::Vector{Dates.DateTime}
end

struct StateVariableValueCondition <: AbstractEventCondition
    variable::VariableType
    device_type::Type{<:PSY.Device}
    value::Float64
end

struct DiscreteEvent <: AbstractEventCondition
    condition_function::Function
    value::Float64
end

mutable struct EventModel{D <: PSY.Contingency, B <: AbstractEventCondition}
    condition::B
    attribute_device_map::Dict{Symbol, Dict{Base.UUID, Dict{DataType, String}}}
    attributes::Dict{String, Any}

    function EventModel(
        ::Type{D},
        condition::B;
        attributes = Dict{String, Any}(),
    ) where {D <: PSY.Contingency, B <: AbstractEventCondition}
        new{D, B}(
            condition,
            Dict{Symbol, Dict{Base.UUID, Dict{DataType, String}}}(),
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
