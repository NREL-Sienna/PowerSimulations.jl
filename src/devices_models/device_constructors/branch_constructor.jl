construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{B, Br},
    ::Type{CopperPlatePowerModel},
) where {B <: PSY.DCBranch, Br <: AbstractBranchFormulation} = nothing

construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{B, Br},
    ::Type{CopperPlatePowerModel},
) where {B <: PSY.ACBranch, Br <: AbstractBranchFormulation} = nothing

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{B, Br},
    ::Type{S},
) where {B <: PSY.Branch, Br <: AbstractBranchFormulation, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(B, sys)

    if validate_available_devices(devices, B)
        return
    end

    branch_rate_bounds!(psi_container, devices, Br, S)
    branch_rate_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
    ::Type{S},
) where {S <: PM.AbstractPowerModel}
    devices = PSY.get_components(PSY.MonitoredLine, sys)

    if validate_available_devices(devices, PSY.MonitoredLine)
        return
    end

    branch_rate_bounds!(psi_container, devices, model.formulation, S)

    branch_rate_constraints!(psi_container, devices, model, S, get_feedforward(model))

    branch_flow_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end

construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    ::DeviceModel{
        <:PSY.Branch,
        <:Union{Type{StaticLineUnbounded}, Type{StaticTransformerUnbounded}},
    },
    ::Type{<:PM.AbstractPowerModel};
    parameters::Union{Nothing, OperationsProblemParameters} = nothing,
) = nothing

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{B, Br},
    ::Type{S},
) where {B <: PSY.DCBranch, Br <: AbstractBranchFormulation, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(B, sys)

    if validate_available_devices(devices, B)
        return
    end

    branch_rate_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end
