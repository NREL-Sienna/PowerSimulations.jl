const DevicesModelContainer = Dict{Symbol, DeviceModel}
const BranchModelContainer = Dict{Symbol, DeviceModelForBranches}
const ServicesModelContainer = Dict{Tuple{String, Symbol}, ServiceModel}

"""
    OperationsProblemTemplate(::Type{T}) where {T<:PM.AbstractPowerFormulation}
Creates a model reference of the PowerSimulations Optimization Problem.
# Arguments
- `model::Type{T<:PM.AbstractPowerFormulation}`:
# Example
```julia
template = OperationsProblemTemplate(CopperPlatePowerModel)
```
"""
mutable struct OperationsProblemTemplate
    transmission::Type{<:PM.AbstractPowerModel}
    devices::DevicesModelContainer
    branches::BranchModelContainer
    services::ServicesModelContainer
    function OperationsProblemTemplate(::Type{T}) where {T <: PM.AbstractPowerModel}
        new(T, DevicesModelContainer(), BranchModelContainer(), ServicesModelContainer())
    end
end

OperationsProblemTemplate() = OperationsProblemTemplate(CopperPlatePowerModel)
# TODO: make getter functions here
# Note: use the file test_operations_template to test the getter functions
get_transmission_model(template::OperationsProblemTemplate) = template.transmission

# Note to devs. PSY exports set_model! these names are choosen to avoid name clashes

"""Sets the transmission model in a template"""
function set_transmission_model!(
    template::OperationsProblemTemplate,
    model::Type{<:PM.AbstractPowerModel},
)
    template.transmission = model
    return
end

"""
    Sets the device model in a template using the component type and formulation.
    Builds a default DeviceModel
"""
function set_device_model!(
    template::OperationsProblemTemplate,
    component_type::Type{<:PSY.StaticInjection},
    formulation::Type{<:AbstractDeviceFormulation},
)
    set_device_model!(template, DeviceModel(component_type, formulation))
    return
end

"""
    Sets the device model in a template using a DeviceModel instance
"""
function set_device_model!(
    template::OperationsProblemTemplate,
    model::DeviceModel{<:PSY.Device, <:AbstractDeviceFormulation},
)
    _set_model!(template.devices, model)
    return
end

function set_device_model!(
    template::OperationsProblemTemplate,
    model::DeviceModel{<:PSY.Branch, <:AbstractDeviceFormulation},
)
    _set_model!(template.branches, model)
    return
end

"""
    Sets the service model in a template using a name and the service type and formulation. Builds a default ServiceModel with use_service_name set to true.
"""
function set_service_model!(
    template::OperationsProblemTemplate,
    service_name::String,
    service_type::Type{<:PSY.Service},
    formulation::Type{<:AbstractServiceFormulation},
)
    set_service_model!(
        template,
        service_name,
        ServiceModel(service_type, formulation, use_service_name = true),
    )
    return
end

"""
    Sets the service model in a template using a ServiceModel instance.
"""
function set_service_model!(
    template::OperationsProblemTemplate,
    service_type::Type{<:PSY.Service},
    formulation::Type{<:AbstractServiceFormulation},
)
    set_service_model!(template, ServiceModel(service_type, formulation))
    return
end

function set_service_model!(
    template::OperationsProblemTemplate,
    service_name::String,
    model::ServiceModel{<:PSY.Service, <:AbstractServiceFormulation},
)
    _set_model!(template.services, service_name, model)
    return
end

function set_service_model!(
    template::OperationsProblemTemplate,
    model::ServiceModel{<:PSY.Service, <:AbstractServiceFormulation},
)
    _set_model!(template.services, model)
    return
end
