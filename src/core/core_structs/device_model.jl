abstract type AbstractDeviceFormulation end

mutable struct DeviceModel{D <: PSY.PowerSystemDevice,
                           B <: PSI.AbstractDeviceFormulation}
    device::Type{D}
    formulation::Type{B}
end
