function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, devices::Array{D,1}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: CopperPlatePowerModel, D <: PowerSystems.Branch}

    copperplatebalance(m, netinjection, sys.time_periods)

end

#=
for t in time_range, (ix,branch) in enumerate(fbr.axes[1])

    !isassigned(netinjection.var_active,devices[ix].connectionpoints.from.number,t) ? netinjection.var_active[devices[ix].connectionpoints.from.number,t] = -fbr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[devices[ix].connectionpoints.from.number,t],-fbr[branch,t])
    !isassigned(netinjection.var_active,devices[ix].connectionpoints.to.number,t) ? netinjection.var_active[devices[ix].connectionpoints.to.number,t] = fbr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[devices[ix].connectionpoints.to.number,t],fbr[branch,t])

end
=#