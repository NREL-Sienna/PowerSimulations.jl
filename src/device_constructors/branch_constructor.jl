function construct_device!(ps_m::CanonicalModel,
                           category::Type{B},
                           category_formulation::Type{Br},
                           system_formulation::Type{StandardPTDFModel},
                           sys::PSY.PowerSystem;
                           kwargs...) where {Br <: AbstractLineForm,
                                             B <: PSY.Branch}


        time_range = 1:sys.time_periods
        line_rate_constraints(ps_m, sys.branches, category_formulation, system_formulation,  time_range)

    #dc_networkflow(m, netinjection, PTDF)

end
