abstract type AbstractDeviceForm end

function _validate_device_formulation(device_model::Type{D}) where {D<:Union{AbstractDeviceForm, PSY.Device}}

    if !isconcretetype(device_model)
        throw(ArgumentError( "the device model must containt only concrete types, $(device_model) is an Abstract Type"))
    end

end

mutable struct DeviceModel{D<:PSY.Device,
                           B<:AbstractDeviceForm}
    device::Type{D}
    formulation::Type{B}
    feedforward::Union{Nothing, FeedForwardModel}

    function DeviceModel(::Type{D},
                         ::Type{B},
                         feedforward::Union{Nothing, F}) where {D<:PSY.Device,
                                                                B<:AbstractDeviceForm,
                                                                F<:FeedForwardModel}

    _validate_device_formulation(D)
    _validate_device_formulation(B)

    new{D, B}(D, B, feedforward)

    end

end

function DeviceModel(::Type{D},
                     ::Type{B}) where {D<:PSY.Device,
                                       B<:AbstractDeviceForm}

                    _validate_device_formulation(D)
                    _validate_device_formulation(B)

    return DeviceModel(D, B, nothing)

end
