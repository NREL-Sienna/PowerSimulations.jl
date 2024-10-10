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
