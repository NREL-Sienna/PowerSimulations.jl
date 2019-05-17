abstract type AbstractOperationsModel end

mutable struct ModelReference{T <: PM.AbstractPowerFormulation}
    transmission::Type{T}
    devices::Dict{Symbol, DeviceModel}
    branches::Dict{Symbol, DeviceModel}
    services::Dict{Symbol, ServiceModel}
end


mutable struct OperationModel{M <: AbstractOperationsModel}
    op_model::Type{M}
    model_ref::ModelReference
    sys::PSY.System
    resolution::Dates.Period
    canonical_model::CanonicalModel

    function OperationModel(op_model::Type{M},
                                model_ref::ModelReference,
                                sys::PSY.System;
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing,
                                kwargs...) where {M <: AbstractOperationsModel,
                                                  T <: PM.AbstractPowerFormulation}

        resolution = collect(keys(sys.forecasts))[1][1]

        ps_model = build_canonical_model(model_ref.transmission,
                                         model_ref.devices,
                                         model_ref.branches,
                                         model_ref.services,
                                        sys,
                                        resolution,
                                        optimizer;
                                        kwargs...)

        new{M}(op_model,
               model_ref,
               sys,
               resolution,
               ps_model)

    end

end