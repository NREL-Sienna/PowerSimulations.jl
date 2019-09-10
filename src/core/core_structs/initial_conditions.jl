abstract type InitialConditionQuantity end
struct DevicePower <: InitialConditionQuantity end
struct DeviceStatus <: InitialConditionQuantity end
struct TimeDurationON <: InitialConditionQuantity end
struct TimeDurationOFF <: InitialConditionQuantity end
struct DeviceEnergy <: InitialConditionQuantity end

mutable struct InitialCondition{T<:Union{PJ.ParameterRef, Float64}}
    device::PSY.Device
    access_ref::UpdateRef
    value::T
    cache::Union{Nothing, AbstractCache}
end

function InitialCondition(device::PSY.Device, access_ref::UpdateRef, value::T) where {T<:Union{PJ.ParameterRef, Float64}}
    return InitialCondition(device, access_ref, value, nothing)
end

struct ICKey{IC<:InitialConditionQuantity, D<:PSY.Device}
    quantity::Type{IC}
    device_type::Type{D}
end

const DICKDA = Dict{ICKey, Array{InitialCondition}}

function value(p::InitialCondition{Float64})
    return p.value
end

function value(p::InitialCondition{PJ.ParameterRef})
    return PJ.value(p.value)
end

get_condition(ic::InitialCondition) = ic.value

device_name(ini_cond::InitialCondition) = PSY.get_name(ini_cond.device)
