function rate_constraints(ps_m::CanonicalModel, devices::Array{Br,1}, device_formulation::Type{PSI.StandardPTDFModel}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {H <: PSY.HydroGen, D <: AbstractHydroDispatchForm, S <: PM.AbstractPowerFormulation}
    rate_data = [(h.name, (min = -1*h.rate, max = h.rate) for h in devices]

    device_range(ps_m, range_data, time_range, "dc_rate_const", "Fbr")

end

function rate_constraints(ps_m::CanonicalModel, devices::Array{Br,1},
device_formulation::Type{PSI.StandardPTDFModel}, system_formulation::Type{S},
time_range::UnitRange{Int64}) where {H <: PSY.HydroGen, D <: AbstractHydroDispatchForm, S <:
PM.AbstractActivePowerFormulation}

    rate_data = [(h.name, h.rate) for h in devices]

    norm_two_constraint(ps_m, range_data, time_range, "hydro_active_range", "Phy")

end