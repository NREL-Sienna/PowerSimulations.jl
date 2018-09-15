function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: CopperPlatePowerModel}

    copperplatebalance(m, netinjection, sys.time_periods)

end


function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: PM.AbstractDCPForm}

    nodalflowbalance()

end

function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: PM.AbstractDCPLLForm}

    nodalflowbalance()

end


function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: StandardPTDF}

    constructnetwork!(PM.AbstractDCPForm)

end

function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: StandardPTDFLL}

    

    constructnetwork!(PM.AbstractDCPLLForm)

    #=

    calculate PTDF

    add PTDF constraints 

    =#

end