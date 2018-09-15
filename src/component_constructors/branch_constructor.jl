function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.Branch}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {D <: AbstractBranchForm, S <: PM.AbstractPowerFormulation}

    flowvariables(m, sys.branches, system_formulation, sys.time_periods)

    thermalflowlimits(m, sys.branches, system_formulation, sys.time_periods)

    

end