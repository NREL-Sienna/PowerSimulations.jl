
function _internal_device_constructor!(canonical_model::CanonicalModel,
                            model::DeviceModel{B, Br},
                           ::Type{CopperPlatePowerModel},
                           sys::PSY.System;
                           kwargs...) where {B<:PSY.DCBranch,
                                             Br<:AbstractBranchFormulation}
    # This code is meant to do nothing

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                           model::DeviceModel{B, Br},
                           ::Type{CopperPlatePowerModel},
                           sys::PSY.System;
                           kwargs...) where {B<:PSY.ACBranch,
                                             Br<:AbstractBranchFormulation}
    # This code is meant to do nothing

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                           model::DeviceModel{B, Br},
                           ::Type{S},
                           sys::PSY.System;
                           kwargs...) where {B<:PSY.Branch,
                                             Br<:AbstractBranchFormulation,
                                             S<:PM.AbstractPowerFormulation}

    devices = PSY.get_components(B, sys)

    if validate_available_devices(devices,B)
        return
    end

    branch_rate_bounds(canonical_model, devices, Br, S)

    branch_rate_constraint(canonical_model, devices, Br, S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                           model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
                           ::Type{S},
                           sys::PSY.System;
                           kwargs...) where {S<:PM.AbstractPowerFormulation}

    devices = PSY.get_components(PSY.MonitoredLine, sys)

    if validate_available_devices(devices, PSY.MonitoredLine)
        return
    end

    branch_rate_bounds(canonical_model,
                        devices,
                        model.formulation,
                        S)

    branch_rate_constraint(canonical_model,
                        devices,
                        model.formulation,
                        S)

    branch_flow_constraint(canonical_model,
                        devices,
                        model.formulation,
                        S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{B, Br},
                                       ::Type{S},
                                       sys::PSY.System;
                                       kwargs...) where {B<:PSY.Branch,
                                                        Br<:Union{Type{StaticLineUnbounded}, Type{StaticTransformerUnbounded}},
                                                        S<:PM.AbstractPowerFormulation}
    # do nothing
    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                           model::DeviceModel{B, Br},
                           ::Type{S},
                           sys::PSY.System;
                           kwargs...) where {Br<:AbstractBranchFormulation,
                                             B<:PSY.DCBranch,
                                             S<:PM.AbstractPowerFormulation}

    devices = PSY.get_components(B, sys)

    if validate_available_devices(devices, B)
        return
    end

    branch_rate_constraint(canonical_model, devices, Br, S)

    return

end
