abstract type AbstractDeviceFormulation end

mutable struct DeviceModel{D <: PSY.PowerSystemDevice,
                           B <: PSI.AbstractDeviceFormulation}
    device::Type{D}
    formulation::Type{B}
end

mutable struct inital_condition
    device::PSY.PowerSystemDevice
    value::ParameterJuMP.Parameter
end