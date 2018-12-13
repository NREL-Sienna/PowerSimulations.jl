"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function activepower(ps_m::canonical_model, devices::Array{H,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {H <: PowerSystems.HydroGen, D <: AbstractHydroDispatchForm, S <: PM.AbstractPowerFormulation}

    activepower_range(ps_m, devices, time_range, "hydro_active_range", "Phy")

end

"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function reactivepower(ps_m::canonical_model,, devices::Array{H,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {H <: PowerSystems.HydrolGen, D <: AbstractHydroDispatchForm, S <: AbstractACPowerModel}

    reactivepower_range(ps_m, devices, time_range, "hydro_reactive_range", "Qhy")

end