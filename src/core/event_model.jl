abstract type AbstractEventCondition end

"""
    ContinuousCondition()

Establishes an event condition that is triggered at all timesteps.  
"""
struct ContinuousCondition <: AbstractEventCondition end

"""
    PresetTimeCondition(time_stamps::Vector{Dates.DateTime})

Establishes an event condition that is triggered at pre-determined times.  

# Arguments
  - `time_stamps::Vector{Dates.DateTime}`: times when event is triggered
"""
struct PresetTimeCondition <: AbstractEventCondition
    time_stamps::Vector{Dates.DateTime}
end

get_time_stamps(c::PresetTimeCondition) = c.time_stamps

"""
    StateVariableValueCondition(
        variable_type::Type{<:VariableType}
        device_type::Type{<:PSY.Device}
        device_name::String
        value::Float64
    )

Establishes an event condition that is triggered if a variable of type `variable_type` for a device of type
`device_type` and name `device_name` is equal to `value`.
and name 

# Arguments
  - `variable_type::Type{<:VariableType}`: variable to be monitored
  - `device_type::Type{<:PSY.Device}`: device type to be monitored
  - `device_name::String`: name of monitored device
  - `value::Float64`: value to compare to in p.u.
"""
struct StateVariableValueCondition <: AbstractEventCondition
    variable_type::VariableType
    device_type::Type{<:PSY.Device}
    device_name::String
    value::Float64
end

get_variable_type(c::StateVariableValueCondition) = c.variable_type
get_device_type(c::StateVariableValueCondition) = c.device_type
get_device_name(c::StateVariableValueCondition) = c.device_name
get_value(c::StateVariableValueCondition) = c.value

"""
    DiscreteEventCondition(condition_function::Function)

Establishes an event condition that is triggered if when a user defined function evaluates to true.
The function should take SimulationState as its only arguement and return true when the event should be triggered and false otherwise.

# Arguments
  - `condition_function::Function`: user defined function `f(::SimulationState)`to determine if event is triggered.
"""
struct DiscreteEventCondition <: AbstractEventCondition
    condition_function::Function
end

get_condition_function(c::DiscreteEventCondition) = c.condition_function

mutable struct EventModel{D <: PSY.Contingency, B <: AbstractEventCondition}
    condition::B
    timeseries_mapping::Dict{Symbol, Union{String, Nothing}}
    attribute_device_map::Dict{Symbol, Dict{Base.UUID, Dict{DataType, Set{String}}}}
    attributes::Dict{String, Any}

    function EventModel(
        contingency_type::Type{D},
        condition::B;
        timeseries_mapping = get_empty_timeseries_mapping(contingency_type),
        attributes = Dict{String, Any}(),
    ) where {D <: PSY.Contingency, B <: AbstractEventCondition}
        new{D, B}(
            condition,
            timeseries_mapping,
            Dict{Symbol, Dict{Base.UUID, Dict{DataType, Set{String}}}}(),
            attributes,
        )
    end
end

function get_empty_timeseries_mapping(
    ::Type{PSY.FixedForcedOutage},
)
    return Dict{Symbol, Union{String, Nothing}}(
        :outage_status => nothing,
    )
end

function get_empty_timeseries_mapping(
    ::Type{PSY.GeometricDistributionForcedOutage},
)
    return Dict{Symbol, Union{String, Nothing}}(
        :mean_time_to_recovery => nothing,
        :outage_transition_probability => nothing,
    )
end

get_event_type(
    ::EventModel{D, B},
) where {D <: PSY.Contingency, B <: AbstractEventCondition} = D

get_event_condition(
    e::EventModel{D, B},
) where {D <: PSY.Contingency, B <: AbstractEventCondition} = e.condition

get_attribute_device_map(e::EventModel) = e.attribute_device_map
