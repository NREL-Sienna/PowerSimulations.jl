construct_device!(op_model::OperationModel,
                  model::DeviceModel{B, Br},
                  ::Type{CopperPlatePowerModel};
                  kwargs...) where {B<:PSY.DCBranch,
                                    Br<:AbstractBranchFormulation} = nothing

construct_device!(op_model::OperationModel,
                  model::DeviceModel{B, Br},
                  ::Type{CopperPlatePowerModel};
                  kwargs...) where {B<:PSY.ACBranch,
                                    Br<:AbstractBranchFormulation} = nothing

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{B, Br},
                           ::Type{S};
                           kwargs...) where {B<:PSY.Branch,
                                             Br<:AbstractBranchFormulation,
                                             S<:PM.AbstractPowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(B, sys)

    if validate_available_devices(devices,B)
        return
    end

    branch_rate_bounds(op_model.canonical, devices, Br, S)

    branch_rate_constraint(op_model.canonical, devices, Br, S)

    return

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
                           ::Type{S};
                           kwargs...) where {S<:PM.AbstractPowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(PSY.MonitoredLine, sys)

    if validate_available_devices(devices, PSY.MonitoredLine)
        return
    end

    branch_rate_bounds(op_model.canonical,
                        devices,
                        model.formulation,
                        S)

    branch_rate_constraint(op_model.canonical,
                        devices,
                        model.formulation,
                        S)

    branch_flow_constraint(op_model.canonical,
                        devices,
                        model.formulation,
                        S)

    return

end

 construct_device!(op_model::OperationModel,
                   model::DeviceModel{B, Br},
                   ::Type{S};
                   kwargs...) where {B<:PSY.Branch,
                                     Br<:Union{Type{StaticLineUnbounded},
                                               Type{StaticTransformerUnbounded}},
                                     S<:PM.AbstractPowerModel} = nothing

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{B, Br},
                           ::Type{S};
                           kwargs...) where {Br<:AbstractBranchFormulation,
                                             B<:PSY.DCBranch,
                                             S<:PM.AbstractPowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(B, sys)

    if validate_available_devices(devices, B)
        return
    end

    branch_rate_constraint(op_model.canonical, devices, Br, S)

    return

end
