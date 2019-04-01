abstract type AbstractDeviceFormulation end

mutable struct DeviceModel{D <: PSY.PowerSystemDevice,
                           B <: PSI.AbstractDeviceFormulation}
    device::Type{D}
    formulation::Type{B}
end

mutable struct InitialCondition
    device::PSY.PowerSystemDevice
    value::Union{PJ.Parameter, Float64}
end