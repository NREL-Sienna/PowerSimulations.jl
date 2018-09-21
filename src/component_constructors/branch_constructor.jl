function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.Branch}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem, args...) where {D <: AbstractBranchForm, S <: PM.AbstractDCPForm}

    flowvariables(m, system_formulation, sys.branches, sys.time_periods)

    thermalflowlimits(m, system_formulation, sys.branches, sys.time_periods)

    nodalflowbalance(m, netinjection, system_formulation, sys)

end

#=
function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.Branch}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem, args...) where {D <: AbstractBranchForm, S <: PM.AbstractDCPLLForm}

    flowvariables(m, system_formulation, sys.branches, sys.time_periods)

    thermalflowlimits(m, system_formulation, sys.branches, sys.time_periods)

    nodalflowbalance(m, netinjection, system_formulation, sys)

end
=#

function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.Line}, category_formulation::Type{PiLine}, system_formulation::Type{StandardPTDF}, sys::PowerSystems.PowerSystem, args...)

    PTDF = [a.second for a in args if a.first == :PTDF][1]

    ac_branches_set = [b.name for b in sys.branches if isa(b,category)]

    println(PTDF)

    isempty(PTDF) ? @error("NO PTDF matrix has been provided") : (size(PTDF)[1] != length(ac_branches_set) ? @error("PTDF size is inconsistent") : true)

    constructdevice!(m, netinjection, category.device, category.formulation, PM.AbstractDCPForm, sys)

end
