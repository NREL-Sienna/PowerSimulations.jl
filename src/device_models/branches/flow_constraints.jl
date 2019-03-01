function line_flow_limit(ps_m::CanonicalModel,
                         devices::Array{Br,1},
                         device_formulation::Type{D},
                         system_formulation::Type{S},
                         time_range::UnitRange{Int64}) where {Br <: PSY.MonitoredLine,
                                                               D <: AbstractBranchFormulation,
                                                               S <: AbstractPowerFormulation}

#rate_data = [(h.name, (min = -1*h.rate, max = h.rate) for h in devices]

device_range(ps_m, range_data, time_range, "dc_rate_const", "Fbr")

end