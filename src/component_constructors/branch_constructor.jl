function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.Branch}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {D <: AbstractBranchForm, S <: PM.AbstractDCPForm}

    flowvariables(m, system_formulation, sys.branches, sys.time_periods)

    thermalflowlimits(m, system_formulation, sys.branches, sys.time_periods)


end


function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.Branch}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {D <: AbstractBranchForm, S <: PM.AbstractDCPLLForm}

    flowvariables(m, system_formulation, sys.branches, sys.time_periods)

    thermalflowlimits(m, system_formulation, sys.branches, sys.time_periods)

    
end