abstract type AbstractOperationsModel end

mutable struct OperationModel{M <: AbstractOperationsModel,
                              T <: PM.AbstractPowerFormulation}
    op_model::Type{M}
    transmission::Type{T}
    devices::Dict{Symbol, DeviceModel}
    branches::Dict{Symbol, DeviceModel}
    services::Dict{Symbol, ServiceModel}
    sys::PSY.System
    resolution::Dates.Period
    canonical_model::CanonicalModel

    function OperationModel(op_model::Type{M},
                                transmission::Type{T},
                                devices::Dict{Symbol, DeviceModel},
                                branches::Dict{Symbol, DeviceModel},
                                services::Dict{Symbol, ServiceModel},
                                sys::PSY.System;
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing,
                                kwargs...) where {M <: AbstractOperationsModel,
                                                  T <: PM.AbstractPowerFormulation}


        resolution = collect(keys(sys.forecasts))[1][1]

        ps_model = build_canonical_model(transmission,
                                        devices,
                                        branches,
                                        services,
                                        sys,
                                        resolution,
                                        optimizer;
                                        kwargs...)

        new{M, T}(op_model,
                  transmission,
                  devices,
                  branches,
                  services,
                  sys,
                  resolution,
                  ps_model)

    end

end
