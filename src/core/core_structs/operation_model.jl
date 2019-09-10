abstract type AbstractOperationModel end

struct DefaultOpModel<:AbstractOperationModel end

mutable struct ModelReference{T<:PM.AbstractPowerFormulation}
    transmission::Type{T}
    devices::Dict{Symbol, DeviceModel}
    branches::Dict{Symbol, DeviceModel}
    services::Dict{Symbol, ServiceModel}
end

function ModelReference(::Type{T}) where {T<:PM.AbstractPowerFormulation}

    return  ModelReference(T,
                           Dict{Symbol, DeviceModel}(),
                           Dict{Symbol, DeviceModel}(),
                           Dict{Symbol, ServiceModel}())

end

mutable struct OperationModel{M<:AbstractOperationModel}
    op_model::Type{M}
    model_ref::ModelReference
    sys::PSY.System
    canonical::CanonicalModel
end

function OperationModel(::Type{M},
                        model_ref::ModelReference,
                        sys::PSY.System;
                        optimizer::Union{Nothing, JuMP.OptimizerFactory}=nothing,
                        kwargs...) where {M<:AbstractOperationModel,
                                          T<:PM.AbstractPowerFormulation}

    verbose = get(kwargs, :verbose, true)
    canonical = _build_canonical(model_ref.transmission,
                                model_ref.devices,
                                model_ref.branches,
                                model_ref.services,
                                sys,
                                optimizer,
                                verbose;
                                kwargs...)

    return  OperationModel(M, model_ref, sys, canonical)

end

function OperationModel(op_model::Type{M},
                        ::Type{T},
                        sys::PSY.System;
                        kwargs...) where {M<:AbstractOperationModel,
                                          T<:PM.AbstractPowerFormulation}

    optimizer = get(kwargs, :optimizer, nothing)

    return OperationModel(op_model,
                          ModelReference(T),
                          sys,
                          CanonicalModel(T, sys, optimizer; kwargs...))

end

function OperationModel(::Type{T},
                        sys::PSY.System;
                        kwargs...) where {T<:PM.AbstractPowerFormulation}


    return OperationModel(DefaultOpModel,
                         T,
                         sys; kwargs...)

end

get_transmission_ref(op_model::OperationModel) = op_model.model_ref.transmission
get_devices_ref(op_model::OperationModel) = op_model.model_ref.devices
get_branches_ref(op_model::OperationModel) = op_model.model_ref.branches
get_services_ref(op_model::OperationModel) = op_model.model_ref.services
get_system(op_model::OperationModel) = op_model.sys

function set_transmission_ref!(op_model::OperationModel,
                               transmission::Type{T}; kwargs...) where {T<:PM.AbstractPowerFormulation}
    op_model.model_ref.transmission = transmission
    build_op_model!(op_model; kwargs...)
    return
end

function set_devices_ref!(op_model::OperationModel, devices::Dict{Symbol, DeviceModel}; kwargs...)
    op_model.model_ref.devices = devices
    build_op_model!(op_model; kwargs...)
    return
end

function set_branches_ref!(op_model::OperationModel, branches::Dict{Symbol, DeviceModel}; kwargs...)
    op_model.model_ref.branches = branches
    build_op_model!(op_model; kwargs...)
    return
end

function add_services_ref!(op_model::OperationModel, services::Dict{Symbol, DeviceModel}; kwargs...)
    op_model.model_ref.services = services
    build_op_model!(op_model; kwargs...)
    return
end

function set_device_model!(op_model::OperationModel,
                           name::Symbol,
                           device::DeviceModel{D, B}; kwargs...) where {D<:PSY.Injection,
                                                                        B<:AbstractDeviceFormulation}

    if haskey(op_model.model_ref.devices, name)
        op_model.model_ref.devices[name] = device
        build_op_model!(op_model; kwargs...)
    else
        error("Device Model with name $(name) doesn't exist in the model")
    end

    return

end

function set_branch_model!(op_model::OperationModel,
                           name::Symbol,
                           branch::DeviceModel{D, B}) where {D<:PSY.Branch,
                                                             B<:AbstractDeviceFormulation}

    if haskey(op_model.model_ref.devices, name)
        op_model.model_ref.branches[name] = branch
        build_op_model!(op_model)
    else
        error("Branch Model with name $(name) doesn't exist in the model")
    end

    return

end

function set_services_model!(op_model::OperationModel,
                             name::Symbol,
                             service::DeviceModel)
    if haskey(op_model.model_ref.devices, name)
        op_model.model_ref.services[name] = service
        build_op_model!(op_model)
    else
        error("Branch Model with name $(name) doesn't exist in the model")
    end

    return

end

function construct_device!(op_model::OperationModel,
                           name::Symbol,
                           device_model::DeviceModel;
                           kwargs...)

    if haskey(op_model.model_ref.devices, name)
        error("Device with model name $(name) already exists in the Opertaion Model")
    end

    _internal_device_constructor!(op_model.canonical,
                                  device_model,
                                  get_transmission_ref(op_model),
                                  get_system(op_model);
                                  kwargs...)

    JuMP.@objective(op_model.canonical.JuMPmodel,
                    MOI.MIN_SENSE,
                    op_model.canonical.cost_function)

    return

end

function get_initial_conditions(op_model::OperationModel)
    return op_model.canonical.initial_conditions
end

function get_initial_conditions(op_model::OperationModel, ic::InitialConditionQuantity, device::PSY.Device)
    canonical = op_model.canonical
    key = ICKey(ic, device)
    return get_ini_cond(canonical, key)
end
