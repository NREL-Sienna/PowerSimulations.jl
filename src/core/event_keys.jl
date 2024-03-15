abstract type EventType end

struct EventKey{T <: EventType, U <: Union{PSY.Component, PSY.System}}
    meta::String
end

function EventKey(
    ::Type{T},
    ::Type{U},
) where {T <: EventType, U <: Union{PSY.Component, PSY.System}}
    if isabstracttype(U)
        error("Type $U can't be abstract")
    end
    return EventKey{T, U}("")
end

get_entry_type(
    ::EventKey{T, U},
) where {T <: EventType, U <: Union{PSY.Component, PSY.System}} = T
get_component_type(
    ::EventKey{T, U},
) where {T <: EventType, U <: Union{PSY.Component, PSY.System}} = U
