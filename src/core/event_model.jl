abstract type AbstractEventModel end
struct TotalOutage <: AbstractEventModel end

mutable struct EventModel{D <: PSY.Contingency, B <: AbstractEventModel}
    attributes::Dict{String, Any}

    function EventModel(
        ::Type{D},
        ::Type{B};
        attributes = Dict{String, Any}(),
    ) where {D <: PSY.Contingency, B <: AbstractEventModel}
        new{D, B}(attributes)
    end
end

get_event_type(
    ::EventModel{D, B},
) where {D <: PSY.Contingency, B <: AbstractEventModel} = D

get_event_model(
    ::EventModel{D, B},
) where {D <: PSY.Contingency, B <: AbstractEventModel} = B
