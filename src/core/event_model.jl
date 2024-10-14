abstract type AbstractEventModel end
struct TotalOutage <: AbstractEventModel end

mutable struct EventModel{D <: PSY.SupplementalAttribute, B <: AbstractEventModel}
    attributes::Dict{String, Any}

    function EventModel(
        ::Type{D},
        ::Type{B};
        attributes = Dict{String, Any}(),
    ) where {D <: PSY.SupplementalAttribute, B <: AbstractEventModel}
        new{D, B}(attributes)
    end
end

get_event_type(
    ::EventModel{D, B},
) where {D <: PSY.SupplementalAttribute, B <: AbstractEventModel} = D
get_formulation(
    ::EventModel{D, B},
) where {D <: PSY.SupplementalAttribute, B <: AbstractEventModel} = B
