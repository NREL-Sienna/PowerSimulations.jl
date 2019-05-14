abstract type AbstractDeviceFormulation end

mutable struct DeviceModel{D <: PSY.Device,
                           B <: PSI.AbstractDeviceFormulation}
    device::Type{D}
    formulation::Type{B}
end

mutable struct InitialCondition{T <: Union{PJ.ParameterRef, Float64}}
    device::PSY.Device
    value::T
end
