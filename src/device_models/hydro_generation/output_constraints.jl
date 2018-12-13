"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function activepower(ps_m::canonical_model, devices::Array{H,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {H <: PowerSystems.HydroGen, D <: AbstractHydroDispatchForm, S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_range(ps_m, range_data, time_range, "hydro_active_range", "Phy")

end

"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function reactivepower(ps_m::canonical_model, devices::Array{H,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {H <: PowerSystems.HydroGen, D <: AbstractHydroDispatchForm, S <: AbstractACPowerModel}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_range(ps_m, range_data, time_range, "hydro_reactive_range", "Qhy")

end