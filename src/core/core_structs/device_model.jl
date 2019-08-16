######## Structs for Formulation feedforward ########
abstract type FeedForwardModel end

struct Range <: FeedForwardModel end
struct SemiContinuousRange <: FeedForwardModel end

abstract type AbstractDeviceFormulation end

function _validate_device_formulation(device_model::Type{D}) where {D<:Union{AbstractDeviceFormulation, PSY.Device}}

    if !isconcretetype(device_model)
        throw(ArgumentError( "the device model must containt only concrete types, $(device_model) is an Abstract Type"))
    end

end

mutable struct DeviceModel{D<:PSY.Device,
                           B<:AbstractDeviceFormulation}
    device::Type{D}
    formulation::Type{B}
    feedforward::Union{Nothing, Type{<: FeedForwardModel}}

    function DeviceModel(::Type{D},
                         ::Type{B},
                         feedforward::Union{Nothing, Type{F}}) where {D<:PSY.Device,
                                                                      B<:AbstractDeviceFormulation,
                                                                      F<:FeedForwardModel}

    _validate_device_formulation(D)
    _validate_device_formulation(B)
    new{D, B}(D, B, feedforward)

    end

end

function DeviceModel(::Type{D},
                     ::Type{B}) where {D<:PSY.Device,
                                       B<:AbstractDeviceFormulation}

                    _validate_device_formulation(D)
                    _validate_device_formulation(B)

    return DeviceModel(D, B, nothing)

end

mutable struct InitialCondition{T<:Union{PJ.ParameterRef, Float64}}
    device::PSY.Device
    value::T
end

function value(p::InitialCondition{Float64})
    return p.value
end

function value(p::InitialCondition{PJ.ParameterRef})
    return PJ.value(p.value)
end

get_condition(ic::InitialCondition) = ic.value
