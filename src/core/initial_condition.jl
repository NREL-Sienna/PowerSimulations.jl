struct InitialCondition{T <: InitialConditionType, V <: Union{PJ.ParameterRef, Float64}}
    device::PSY.Component
    value::V
    cache_type::Union{Nothing, Type{<:AbstractCache}}
end

function InitialCondition(
    ::Type{T},
    device::PSY.Component,
    value::V,
) where {T <: InitialConditionType, V <: Union{PJ.ParameterRef, Float64}}
    return InitialCondition{T, V}(device, value, nothing)
end

function InitialCondition(
    ::ICKey{T, U},
    device::U,
    value::V,
    cache_type::Union{Nothing, Type{<:AbstractCache}},
) where {
    T <: InitialConditionType,
    V <: Union{PJ.ParameterRef, Float64},
    U <: PSY.Component,
}
    return InitialCondition{T, V}(device, value, cache_type)
end

function get_condition(p::InitialCondition{T, Float64}) where {T <: InitialConditionType}
    return p.value
end

function get_condition(
    p::InitialCondition{T, PJ.ParameterRef},
) where {T <: InitialConditionType}
    return PJ.value(p.value)
end

get_device(ic::InitialCondition) = ic.device
get_value(ic::InitialCondition) = ic.value
get_device_name(ic::InitialCondition) = PSY.get_name(ic.device)
