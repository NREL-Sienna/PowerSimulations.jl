function get_available_components(::Type{T}, sys::PSY.System) where {T <: PSY.Component}
    return PSY.get_components(T, sys, x -> PSY.get_available(x))
end

function get_available_components(
    ::Type{PSY.RegulationDevice{T}},
    sys::PSY.System,
) where {T <: PSY.Component}
    return PSY.get_components(
        PSY.RegulationDevice{T},
        sys,
        x -> (PSY.get_available(x) && PSY.has_service(x, PSY.AGC)),
    )
end

make_system_filename(sys::PSY.System) = "system-$(IS.get_uuid(sys)).json"
make_system_filename(sys_uuid::Union{Base.UUID, AbstractString}) = "system-$(sys_uuid).json"
