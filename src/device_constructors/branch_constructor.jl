function construct_device!(ps_m::CanonicalModel,
                           device::Type{B},
                           device_formulation::Type{Br},
                           system_formulation::Type{StandardPTDFModel},
                           sys::PSY.PowerSystem, 
                           time_range::UnitRange{Int64};
                           kwargs...) where {Br <: AbstractLineForm,
                                             B <: PSY.Branch}

    line_rate_constraints(ps_m, sys.branches, device_formulation, system_formulation, time_range)

    return nothing

end
