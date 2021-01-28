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
    devices::Dict{String, DeviceModel}
    branches::Dict{String, DeviceModel}
    services::Dict{String, ServiceModel}
    function OperationsProblemTemplate(::Type{T}) where {T <: PM.AbstractPowerModel}
        new(
            T,
            Dict{String, DeviceModel}(),
            Dict{String, DeviceModel}(),
            Dict{String, ServiceModel}(),
        )
    end
end

OperationsProblemTemplate() = OperationsProblemTemplate(CopperPlatePowerModel)

# Note to devs. PSY exports set_model! these names are choosen to avoid name clashes
function set_transmission_model!(
    template::OperationsProblemTemplate,
    model::Type{<:PM.AbstractPowerModel},
)
    template.transmission = model
    return
end

function set_component_model!(
    template::OperationsProblemTemplate,
    label,
    model::DeviceModel{<:PSY.Device, <:AbstractDeviceFormulation},
)
    _set_model!(template.devices, string(label), model)
    return
end

function set_component_model!(
    template::OperationsProblemTemplate,
    label,
    model::DeviceModel{<:PSY.Branch, <:AbstractDeviceFormulation},
)
    _set_model!(template.branches, string(label), model)
end

function set_component_model!(
    template::OperationsProblemTemplate,
    label,
    model::ServiceModel{<:PSY.Service, <:AbstractServiceFormulation},
)
    _set_model!(template.services, string(label), model)
end
