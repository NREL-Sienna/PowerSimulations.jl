
function _internal_device_constructor!(ps_m::CanonicalModel,
                           device::Type{B},
                           device_formulation::Type{Br},
                           system_formulation::Type{CopperPlatePowerModel},
                           sys::PSY.System;
                           kwargs...) where {Br <: AbstractBranchFormulation,
                                             B <: PSY.Branch}
    # This code is meant to do nothing 

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                           device::Type{B},
                           device_formulation::Type{Br},
                           system_formulation::Type{S},
                           sys::PSY.System;
                           kwargs...) where {Br <: AbstractBranchFormulation,
                                             B <: PSY.Branch,
                                             S <: PM.AbstractPowerFormulation}

    devices = PSY.get_components(device, sys)
    
    isempty(devices) && return

    branch_rate_constraint(ps_m,
                        devices,
                        device_formulation,
                        system_formulation)

    return

end

#=
function _internal_device_constructor!(ps_m::CanonicalModel,
                            device::Type{B},
                            device_formulation::Type{Br},
                            system_formulation::Type{S},
                            sys::PSY.System;
                            kwargs...) where {Br <: AbstractBranchFormulation,
                                              B <: PSY.Branch,
                                              S <: PM.AbstractPowerFormulation}


    # This code is meant to do nothing and will have a constructor once the branch formulations are developed

    branch_rate_constraint(ps_m,
                        devices,
                        device_formulation,
                        system_formulation)

    return

end
=#