abstract type AbstractOperationsModel end

mutable struct DeviceModel{D <: PSY.PowerSystemDevice,
                   B <: PSI.AbstractDeviceFormulation}
    device::Type{D}
    formulation::Type{B}
end

mutable struct PowerOperationModel{M <: AbstractOperationsModel,
                                   T <: PM.AbstractPowerFormulation}
    op_model::Type{M}
    transmission::Type{T}
    system::PSY.PowerSystem
    devices::Dict{String, DeviceModel}
    services::Dict{String, DataType}
    canonical_model::PSI.CanonicalModel
end