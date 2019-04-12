function construct_device!(ps_m::CanonicalModel,
                           device::Type{B},
                           device_formulation::Type{Br},
                           system_formulation::Type{StandardPTDFForm},
                           sys::PSY.System,
                           time_range::UnitRange{Int64};
                           kwargs...) where {Br <: AbstractLineForm,
                                             B <: PSY.Branch}

    line_rate_constraints(ps_m, sys.branches, device_formulation, system_formulation, time_range)

    return

end

function construct_device!(ps_m::CanonicalModel,
                            device::Type{B},
                            device_formulation::Type{Br},
                            system_formulation::Type{S},
                            sys::PSY.System,
                            time_range::UnitRange{Int64};
                            kwargs...) where {Br <: AbstractLineForm,
                                              B <: PSY.Branch,
                                              S <: PM.AbstractPowerFormulation}


    # This code is meant to do nothing and will have a constructor once the branch formulations are developed

    return

end
