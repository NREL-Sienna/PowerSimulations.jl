construct_device!(psi_container::PSIContainer, sys::PSY.System,
                  model::DeviceModel{B, Br},
                  ::Type{CopperPlatePowerModel};
                  kwargs...) where {B<:PSY.DCBranch,
                                    Br<:AbstractBranchFormulation} = nothing

construct_device!(psi_container::PSIContainer, sys::PSY.System,
                  model::DeviceModel{B, Br},
                  ::Type{CopperPlatePowerModel};
                  kwargs...) where {B<:PSY.ACBranch,
                                    Br<:AbstractBranchFormulation} = nothing

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{B, Br},
                           ::Type{S};
                           kwargs...) where {B<:PSY.Branch,
                                             Br<:AbstractBranchFormulation,
                                             S<:PM.AbstractPowerModel}
    devices = PSY.get_components(B, sys)

    if validate_available_devices(devices,B)
        return
    end

    branch_rate_bounds!(psi_container, devices, Br, S)
    branch_rate_constraint!(psi_container, devices, Br, S, model.feedforward)

    return
end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
                           ::Type{S};
                           kwargs...) where {S<:PM.AbstractPowerModel}
    devices = PSY.get_components(PSY.MonitoredLine, sys)

    if validate_available_devices(devices, PSY.MonitoredLine)
        return
    end

    branch_rate_bounds!(psi_container,
                        devices,
                        model.formulation,
                        S)

    branch_rate_constraint!(psi_container,
                        devices,
                        model.formulation,
                        S,
                        model.feedforward)

    branch_flow_constraint!(psi_container,
                        devices,
                        model.formulation,
                        S,
                        model.feedforward)

    return
end

 construct_device!(psi_container::PSIContainer, sys::PSY.System,
                   ::DeviceModel{<:PSY.Branch, <:Union{Type{StaticLineUnbounded}, Type{StaticTransformerUnbounded}}},
                   ::Type{<:PM.AbstractPowerModel}) = nothing

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{B, <:AbstractBranchFormulation},
                           ::Type{<:PM.AbstractPowerModel};
                           kwargs...) where B<:PSY.DCBranch
    devices = PSY.get_components(B, sys)

    if validate_available_devices(devices, B)
        return
    end

    branch_rate_constraint!(psi_container, devices, Br, S, model.feedforward)

    return
end
