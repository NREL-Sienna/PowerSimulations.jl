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
    canonical_model::CanonicalModel

    function OperationModel(op_model::Type{M},
                                model_ref::ModelReference,
                                sys::PSY.System;
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing,
                                kwargs...) where {M <: AbstractOperationsModel,
                                                  T <: PM.AbstractPowerFormulation}

        ps_model = build_canonical_model(model_ref.transmission,
                                         model_ref.devices,
                                         model_ref.branches,
                                         model_ref.services,
                                        sys,
                                        optimizer;
                                        kwargs...)

        new{M}(op_model,
               model_ref,
               sys,
               ps_model)

    end

end

get_transmission_ref(op_model::OperationModel) = op_model.model_ref.transmission
get_devices_ref(op_model::OperationModel) = op_model.model_ref.devices
get_branches_ref(op_model::OperationModel) = op_model.model_ref.branches
get_services_ref(op_model::OperationModel) = op_model.model_ref.services

function set_transmission_ref!(op_model::OperationModel, transmission::Type{T}) where {T <: PM.AbstractPowerFormulation} 
    op_model.model_ref.transmission = transmission
    return 
end

function set_devices_ref!(op_model::OperationModel, devices::Dict{Symbol, DeviceModel}) 
    op_model.model_ref.devices = devices
    return
end

function set_branches_ref!(op_model::OperationModel, branches::Dict{Symbol, DeviceModel}) 
    op_model.model_ref.branches = branches
    return
end

function set_services_ref!(op_model::OperationModel, services::Dict{Symbol, DeviceModel}) 
    op_model.model_ref.services = services
    return
end