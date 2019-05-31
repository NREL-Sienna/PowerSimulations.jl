function _internal_device_constructor!(ps_m::CanonicalModel,
                           device::Type{B},
                           device_formulation::Type{Br},
                           system_formulation::Type{StandardPTDFForm},
                           sys::PSY.System,
                           time_steps::UnitRange{Int64},
                           resolution::Dates.Period;
                           kwargs...) where {Br <: AbstractBranchFormulation,
                                             B <: PSY.Branch}

    devices = PSY.get_components(device, sys)
    #=
    branch_rate_constraint(ps_m, 
                          devices, 
                          device_formulation, 
                          system_formulation,
                          time_steps) 
    =#


    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                            device::Type{B},
                            device_formulation::Type{Br},
                            system_formulation::Type{S},
                            sys::PSY.System,
                            time_steps::UnitRange{Int64},
                            resolution::Dates.Period;
                            kwargs...) where {Br <: AbstractBranchFormulation,
                                              B <: PSY.Branch,
                                              S <: PM.AbstractPowerFormulation}


    # This code is meant to do nothing and will have a constructor once the branch formulations are developed

    return

end
