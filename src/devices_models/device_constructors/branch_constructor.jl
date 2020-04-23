construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{<:PSY.ACBranch, <:AbstractBranchFormulation},
    ::Type{CopperPlatePowerModel},
) = nothing

construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{<:PSY.DCBranch, <:AbstractDCLineFormulation},
    ::Type{CopperPlatePowerModel},
) = nothing

# This method might be redundant but added for completness of the formulations
construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    ::DeviceModel{<:PSY.Branch, <:Type{UnboundedBranches}},
    ::Type{<:PM.AbstractPowerModel},
) = nothing

# For DC Power only. Implements Bounds only and constraints
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{B, Br},
    ::Type{S},
) where {
    B <: PSY.ACBranch,
    Br <: AbstractBoundedBranchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = PSY.get_components(B, sys)
    if validate_available_devices(devices, B)
        return
    end
    !isnothing(get_feedforward(model)) &&
        throw(IS.ConflictingInputsError("$(Br) formulation doesn't support FeedForward. Use Constrained Branch Formulation instead"))
    branch_rate_bounds!(psi_container, devices, model, S)
    branch_rate_constraints!(psi_container, devices, model, S, get_feedforward(model))
    return
end

# For DC Power only. Implements Constraints only
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(B, sys)
    if validate_available_devices(devices, B)
        return
    end
    branch_rate_constraints!(psi_container, devices, model, S, get_feedforward(model))
    return
end

# For AC Power only. Implements Bounds on the active power and rating constraints on the aparent power
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(B, sys)
    if validate_available_devices(devices, B)
        return
    end
    branch_rate_bounds!(psi_container, devices, model, S)
    branch_rate_constraints!(psi_container, devices, model, S, get_feedforward(model))
    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{B, Br},
    ::Type{S},
) where {B <: PSY.DCBranch, Br <: AbstractDCLineFormulation, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(B, sys)
    if validate_available_devices(devices, B)
        return
    end
    branch_rate_constraints!(psi_container, devices, model, S, get_feedforward(model))
    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
    ::Type{S},
) where {S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(PSY.MonitoredLine, sys)
    if validate_available_devices(devices, PSY.MonitoredLine)
        return
    end
    branch_flow_constraints!(psi_container, devices, model, S, get_feedforward(model))
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
    branch_rate_constraints!(psi_container, devices, model, S, get_feedforward(model))
    branch_flow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    return
end
