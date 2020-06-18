mutable struct OperationsProblemTemplate
    transmission::Type{<:PM.AbstractPowerModel}
    devices::Dict{Symbol, DeviceModel}
    branches::Dict{Symbol, DeviceModel}
    services::Dict{Symbol, ServiceModel}
end

"""
    OperationsProblemTemplate(::Type{T}) where {T<:PM.AbstractPowerFormulation}
Creates a model reference of the Power Formulation, devices, branches, and services.
# Arguments
- `model::Type{T<:PM.AbstractPowerFormulation}`:
- `devices::Dict{Symbol, DeviceModel}`: device dictionary
- `branches::Dict{Symbol, BranchModel}`: branch dictionary
- `services::Dict{Symbol, ServiceModel}`: service dictionary
# Example
```julia
template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
```
"""
function OperationsProblemTemplate(::Type{T}) where {T <: PM.AbstractPowerModel}
    return OperationsProblemTemplate(
        T,
        Dict{Symbol, DeviceModel}(),
        Dict{Symbol, DeviceModel}(),
        Dict{Symbol, ServiceModel}(),
    )
end

OperationsProblemTemplate() = OperationsProblemTemplate(PM.AbstractPowerModel)

function set_model!(template::OperationsProblemTemplate, label::Symbol, model::DeviceModel)
    if haskey(template.devices, label)
        throw(IS.ConflictingInputsError("Device with model name $(label) already exists in the Opertaion Model"))
    end
    template.devices[label] = model
    return
end

function set_model!(template::OperationsProblemTemplate, model::Type{<:PM.AbstractPowerModel})
    template.transmission = model
    return
end
