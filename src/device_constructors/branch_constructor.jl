function construct_device!(ps_m::CanonicalModel,
                           device::Type{B},
                           device_formulation::Type{Br},
                           system_formulation::Type{StandardPTDFModel},
                           sys::PSY.PowerSystem, 
time_range::UnitRange{Int64};
                           kwargs...) where {Br <: AbstractLineForm,
                                             B <: PSY.Branch}


        time_range = 1:sys.time_periods
        line_rate_constraints(ps_m, sys.branches, device_formulation, system_formulation,  time_range)

    #dc_networkflow(m, netinjection, PTDF)

end
