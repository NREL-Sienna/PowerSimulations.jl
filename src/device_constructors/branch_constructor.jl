function construct_device!(m::JuMP.AbstractModel,
                           category::Type{B},
                           category_formulation::Type{PiLine},
                           system_formulation::Type{StandardPTDFModel},
                           sys::PSY.PowerSystem;
                           kwargs...) where {B <: PSY.Branch}

    thermalflowlimits(m, system_formulation, sys.branches, sys.time_periods)

    dc_networkflow(m, netinjection, PTDF)

end
