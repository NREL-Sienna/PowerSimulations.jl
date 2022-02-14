const DevicesModelContainer = Dict{Symbol, DeviceModel}
const BranchModelContainer = Dict{Symbol, DeviceModelForBranches}
const ServicesModelContainer = Dict{Tuple{String, Symbol}, ServiceModel}

"""
    ProblemTemplate(::Type{T}) where {T<:PM.AbstractPowerFormulation}

Creates a model reference of the PowerSimulations Optimization Problem.

# Arguments

  - `model::Type{T<:PM.AbstractPowerFormulation}`:

# Example

template = ProblemTemplate(CopperPlatePowerModel)
"""
mutable struct ProblemTemplate
    network_model::NetworkModel{<:PM.AbstractPowerModel}
    devices::DevicesModelContainer
    branches::BranchModelContainer
    services::ServicesModelContainer
    function ProblemTemplate(network::NetworkModel{T}) where {T <: PM.AbstractPowerModel}
        new(
            network,
            DevicesModelContainer(),
            BranchModelContainer(),
            ServicesModelContainer(),
        )
    end
end

ProblemTemplate(::Type{T}) where {T <: PM.AbstractPowerModel} =
    ProblemTemplate(NetworkModel(T))
ProblemTemplate() = ProblemTemplate(CopperPlatePowerModel)

get_device_models(template::ProblemTemplate) = template.devices
get_branch_models(template::ProblemTemplate) = template.branches
get_service_models(template::ProblemTemplate) = template.services
get_network_model(template::ProblemTemplate) = template.network_model
get_network_formulation(template::ProblemTemplate) =
    get_network_formulation(get_network_model(template))

function get_model(template::ProblemTemplate, device_type)
    if device_type <: PSY.Device
        return get(template.devices, Symbol(device_type), nothing)
    elseif device_type <: PSY.Branch
        return get(template.branches, Symbol(device_type), nothing)
    elseif device_type <: PSY.Service
        return get(template.services, Symbol(device_type), nothing)
    else
        error("not supported: $device_type")
    end
end

# Note to devs. PSY exports set_model! these names are chosen to avoid name clashes

"""
Sets the network model in a template.
"""
function set_network_model!(
    template::ProblemTemplate,
    model::NetworkModel{<:PM.AbstractPowerModel},
)
    template.network_model = model
    return
end

"""
Sets the device model in a template using the component type and formulation.
Builds a default DeviceModel
"""
function set_device_model!(
    template::ProblemTemplate,
    component_type::Type{<:PSY.Device},
    formulation::Type{<:AbstractDeviceFormulation},
)
    set_device_model!(template, DeviceModel(component_type, formulation))
    return
end

"""
Sets the device model in a template using a DeviceModel instance
"""
function set_device_model!(
    template::ProblemTemplate,
    model::DeviceModel{<:PSY.Device, <:AbstractDeviceFormulation},
)
    _set_model!(template.devices, model)
    return
end

function set_device_model!(
    template::ProblemTemplate,
    model::DeviceModel{<:PSY.Branch, <:AbstractDeviceFormulation},
)
    _set_model!(template.branches, model)
    return
end

"""
Sets the service model in a template using a name and the service type and formulation.
Builds a default ServiceModel with use_service_name set to true.
"""
function set_service_model!(
    template::ProblemTemplate,
    service_name::String,
    service_type::Type{<:PSY.Service},
    formulation::Type{<:AbstractServiceFormulation},
)
    set_service_model!(
        template,
        service_name,
        ServiceModel(service_type, formulation, use_service_name=true),
    )
    return
end

"""
Sets the service model in a template using a ServiceModel instance.
"""
function set_service_model!(
    template::ProblemTemplate,
    service_type::Type{<:PSY.Service},
    formulation::Type{<:AbstractServiceFormulation},
)
    set_service_model!(template, ServiceModel(service_type, formulation))
    return
end

function set_service_model!(
    template::ProblemTemplate,
    service_name::String,
    model::ServiceModel{<:PSY.Service, <:AbstractServiceFormulation},
)
    _set_model!(template.services, service_name, model)
    return
end

function set_service_model!(
    template::ProblemTemplate,
    model::ServiceModel{<:PSY.Service, <:AbstractServiceFormulation},
)
    _set_model!(template.services, model)
    return
end
