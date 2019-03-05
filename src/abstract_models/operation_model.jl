abstract type AbstractOperationsModel end

mutable struct PowerOperationModel{M <: AbstractOperationsModel,
                                   T <: PM.AbstractPowerFormulation}
    op_model::Type{M}
    transmission::Type{T}
    devices::Dict{String, DeviceModel}
    branches::Dict{String, DeviceModel}
    services::Dict{String, DataType}
    system::PSY.PowerSystem
    canonical_model::PSI.CanonicalModel


    function PowerOperationModel(op_model::Type{M},
                                transmission::Type{T},
                                devices::Dict{String, DeviceModel},
                                branches::Dict{String, DeviceModel},
                                services::Dict{String, DataType},
                                system::PSY.PowerSystem,
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing;
                                kwargs...) where {M <: AbstractOperationsModel,
                                                  T <: PM.AbstractPowerFormulation}

        ps_model = build_op_model!(transmission, 
                                   devices, 
                                   branches, 
                                   services, 
                                   system, 
                                   optimizer, 
                                   kwargs...)

        new{M, T}(op_model,
                  transmission,
                  devices,
                  branches,
                  services,
                  system,
                  ps_model)


    end

end

