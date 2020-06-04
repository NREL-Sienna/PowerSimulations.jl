struct InitialCondition{T <: Union{PJ.ParameterRef, Float64}}
    device::PSY.Component
    update_ref::UpdateRef
    value::T
    cache_type::Union{Nothing, Type{<:AbstractCache}}
end

function InitialCondition(
    device::PSY.Device,
    update_ref::UpdateRef,
    value::T,
) where {T <: Union{PJ.ParameterRef, Float64}}
    return InitialCondition(device, update_ref, value, nothing)
end

function get_condition(p::InitialCondition{Float64})
    return p.value
end

function get_condition(p::InitialCondition{PJ.ParameterRef})
    return PJ.value(p.value)
end

get_value(ic::InitialCondition) = ic.value
device_name(ic::InitialCondition) = PSY.get_name(ic.device)
