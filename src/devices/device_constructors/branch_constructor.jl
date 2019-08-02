
function _internal_device_constructor!(ps_m::CanonicalModel,
                           device::Type{B},
                           device_formulation::Type{Br},
                           system_formulation::Type{CopperPlatePowerModel},
                           sys::PSY.System;
                           kwargs...) where {Br<:AbstractBranchFormulation,
                                             B<:PSY.DCBranch}
    # This code is meant to do nothing

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                           device::Type{B},
                           device_formulation::Type{Br},
                           system_formulation::Type{CopperPlatePowerModel},
                           sys::PSY.System;
                           kwargs...) where {Br<:AbstractBranchFormulation,
                                             B<:PSY.ACBranch}
    # This code is meant to do nothing

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                           device::Type{B},
                           device_formulation::Type{Br},
                           system_formulation::Type{S},
                           sys::PSY.System;
                           kwargs...) where {Br<:AbstractBranchFormulation,
                                             B<:PSY.Branch,
                                             S<:PM.AbstractPowerFormulation}

    devices = PSY.get_components(device, sys)

    isempty(devices) && return

    branch_rate_bounds(ps_m,
                        devices,
                        device_formulation,
                        system_formulation)

    branch_rate_constraint(ps_m,
                        devices,
                        device_formulation,
                        system_formulation)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                           device::Type{PSY.MonitoredLine},
                           device_formulation::Type{FlowMonitoredLine},
                           system_formulation::Type{S},
                           sys::PSY.System;
                           kwargs...) where {S<:PM.AbstractPowerFormulation}

    devices = PSY.get_components(device, sys)

    isempty(devices) && return

    branch_rate_bounds(ps_m,
                        devices,
                        device_formulation,
                        system_formulation)

    branch_rate_constraint(ps_m,
                        devices,
                        device_formulation,
                        system_formulation)

    branch_flow_constraint(ps_m,
                        devices,
                        device_formulation,
                        system_formulation)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                           device::Type{B},
                           device_formulation::Union{Type{StaticLineUnbounded}, Type{StaticTransformerUnbounded}},
                           system_formulation::Type{S},
                           sys::PSY.System;
                           kwargs...) where {B<:PSY.Branch,
                                             S<:PM.AbstractPowerFormulation}


    # do nothing
    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                           device::Type{B},
                           device_formulation::Type{Br},
                           system_formulation::Type{S},
                           sys::PSY.System;
                           kwargs...) where {Br<:AbstractBranchFormulation,
                                             B<:PSY.DCBranch,
                                             S<:PM.AbstractPowerFormulation}

    devices = PSY.get_components(device, sys)

    isempty(devices) && return

    branch_rate_constraint(ps_m,
                        devices,
                        device_formulation,
                        system_formulation)

    return

end
