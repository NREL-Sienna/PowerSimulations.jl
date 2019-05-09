abstract type AbstractOperationsModel end

mutable struct PowerOperationModel{M <: AbstractOperationsModel,
                                   T <: PM.AbstractPowerFormulation}
    op_model::Type{M}
    transmission::Type{T}
    devices::Dict{Symbol, DeviceModel}
    branches::Dict{Symbol, DeviceModel}
    services::Dict{Symbol, ServiceModel}
    system::PSY.ConcreteSystem
    canonical_model::CanonicalModel

    function PowerOperationModel(op_model::Type{M},
                                transmission::Type{T},
                                devices::Dict{Symbol, DeviceModel},
                                branches::Dict{Symbol, DeviceModel},
                                services::Dict{Symbol, ServiceModel},
                                system::PSY.ConcreteSystem;
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing,
                                kwargs...) where {M <: AbstractOperationsModel,
                                                  T <: PM.AbstractPowerFormulation}

        ps_model = build_canonical_model(transmission,
                                        devices,
                                        branches,
                                        services,
                                        system,
                                        optimizer;
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
