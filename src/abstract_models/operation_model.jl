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
    devices::Dict{String, DeviceModel}
    branches::Dict{String, DeviceModel}
    services::Dict{String, DataType}
    system::PSY.PowerSystem
    canonical_model::PSI.CanonicalModel
end

function PowerOperationModel(op_model::Type{M},
                             transmission::Type{T},
                             devices::Dict{String, DeviceModel},
                             branches::Dict{String, DeviceModel},
                             services::Dict{String, DataType},
                             system::PSY.PowerSystem; kwargs...) where {M <: AbstractOperationsModel,
                                                                        T <: PM.AbstractPowerFormulation}

    bus_count = length(system.buses)

    ps_model = CanonicalModel(JuMP.Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, bus_count, system.time_periods),
                                                                          "var_reactive" => PSI.JumpAffineExpressionArray(undef, bus_count, system.time_periods)),
                              Dict{String,Any}(),
                              nothing);

    return PowerOperationModel(op_model,
                               transmission,
                               devices,
                               branches,
                               services,
                               system,
                               ps_model)


end

function PowerOperationModel(op_model::Type{M},
                             transmission::Type{T},
                             devices::Dict{String, DeviceModel},
                             branches::Dict{String, DeviceModel},
                             services::Dict{String, DataType},
                             system::PSY.PowerSystem; kwargs...) where {M <: AbstractOperationsModel,
                                                                    T <: PM.AbstractActivePowerFormulation}

    bus_count = length(system.buses)

    ps_model = CanonicalModel(JuMP.Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, bus_count, system.time_periods)),
                              Dict{String,Any}(),
                              nothing);

        return PowerOperationModel(op_model,
                                  transmission,
                                  devices,
                                  branches,
                                  services,
                                  system,
                                  ps_model)

end

function PowerOperationModel(op_model::Type{M},
                             transmission::Type{StandardPTDFModel},
                             devices::Dict{String, DeviceModel},
                             branches::Dict{String, DeviceModel},
                             services::Dict{String, DataType},
                             system::PSY.PowerSystem; kwargs...) where {M <: AbstractOperationsModel}

    bus_count = length(system.buses)

    ps_model = CanonicalModel(JuMP.Model(),
        Dict{String, JuMP.Containers.DenseAxisArray}(),
        Dict{String, JuMP.Containers.DenseAxisArray}(),
        nothing,
        Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, bus_count, system.time_periods)),
        Dict{String,Any}(),
        nothing);

    return PowerOperationModel(op_model,
                               transmission,
                               devices,
                               branches,
                               services,
                               system,
                               ps_model)

end

function PowerOperationModel(op_model::Type{M},
                             transmission::Type{CopperPlatePowerModel},
                             devices::Dict{String, DeviceModel},
                             branches::Dict{String, DeviceModel},
                             services::Dict{String, DataType},
                             system::PSY.PowerSystem; kwargs...) where {M <: AbstractOperationsModel}

    bus_count = length(system.buses)

    ps_model = CanonicalModel(JuMP.Model(),
        Dict{String, JuMP.Containers.DenseAxisArray}(),
        Dict{String, JuMP.Containers.DenseAxisArray}(),
        nothing,
        Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, bus_count, system.time_periods)),
        Dict{String,Any}(),
        nothing);

     return PowerOperationModel(op_model,
                                transmission,
                                devices,
                                branches,
                                services,
                                system,
                                ps_model)


end


