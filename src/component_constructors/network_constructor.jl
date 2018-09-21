function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: CopperPlatePowerModel}

    copperplatebalance(m, netinjection, sys.time_periods)

end

function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: PM.AbstractDCPForm}

    nodalflowbalance(m, netinjection, system_formulation, sys)

end

function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: PM.AbstractDCPLLForm}

    nodalflowbalance(m, netinjection, system_formulation, sys)

end

