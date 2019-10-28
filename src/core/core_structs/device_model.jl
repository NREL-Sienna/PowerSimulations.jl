abstract type AbstractDeviceFormulation end

function _validate_device_formulation(::Type{D})
                                     where {D<:Union{AbstractDeviceFormulation, PSY.Device}}

    if !isconcretetype(D)
        throw(ArgumentError("The device model must contain only concrete types, $(D) is an Abstract Type"))
    end

end

mutable struct DeviceModel{D<:PSY.Device,
                           B<:AbstractDeviceFormulation}
    device::Type{D}
    formulation::Type{B}
    feedforward::Union{Nothing, FeedForwardModel}

    function DeviceModel(::Type{D},
                         ::Type{B},
                         feedforward::Union{Nothing, F}) where {D<:PSY.Device,
                                                                B<:AbstractDeviceFormulation,
                                                                F<:FeedForwardModel}

    _validate_device_formulation(D)
    _validate_device_formulation(B)

    new{D, B}(D, B, feedforward)

    end

end

"""
    DeviceModel(::Type{D}, ::Type{B}) where {D<:PSY.Device,
                                       B<:AbstractDeviceFormulation}
This validates the device formulation for the Power System Device and the
abstract device formulation and returns  Power System Device and the
abstract device formulation if the power system device is a concrete type.

# Arguments
-`::Type{D}`: Power System Device
-`::Type{B}`: Abstract Device Formulation

# Outputs
`DeviceModel(D, B, nothing)`: D::PSY.Device, B::AbstractDeviceFormulation

# Example
```julia
branches = Dict{Symbol, DeviceModel}
    (:L => DeviceModel(PSY.Line, PSI.StaticLine),
    :T => DeviceModel(PSY.Transformer2W, PSI.StaticTransformer),
    :TT => DeviceModel(PSY.TapTransformer , PSI.StaticTransformer),
    :dc_line => DeviceModel(PSY.HVDCLine, PSI.HVDCDispatch))
```
"""

function DeviceModel(::Type{D},
                     ::Type{B}) where {D<:PSY.Device,
                                       B<:AbstractDeviceFormulation}

                    _validate_device_formulation(D)
                    _validate_device_formulation(B)

    return DeviceModel(D, B, nothing)

end
