function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, devices::Array{D,1}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: CopperPlatePowerModel, D <: PowerSystems.Branch}

    copperplatebalance(m, netinjection, sys.time_periods)

end

function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, devices::Array{D,1}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: CopperPlatePowerModel, D <: PowerSystems.Branch}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:sys.time_periods

    fbr = @variable(m, fbr[on_set,time_range])

    for t in time_range, (ix,branch) in enumerate(fbr.axes[1])

        !isassigned(netinjection.var_active,devices[ix].connectionpoints.from.number,t) ? netinjection.var_active[devices[ix].connectionpoints.from.number,t] = -fbr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[devices[ix].connectionpoints.from.number,t],-fbr[branch,t])
        !isassigned(netinjection.var_active,devices[ix].connectionpoints.to.number,t) ? netinjection.var_active[devices[ix].connectionpoints.to.number,t] = fbr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[devices[ix].connectionpoints.to.number,t],fbr[branch,t])

    end

end


function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, devices::Array{D,1}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: CopperPlatePowerModel, D <: PowerSystems.Branch}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:sys.time_periods

    fbr_to = @variable(m, fbr_to[on_set,time_range])
    fbr_fr = @variable(m, fbr_fr[on_set,time_range])

    for t in time_range, (ix,branch) in enumerate(fbr_to.axes[1])

        !isassigned(netinjection.var_active,devices[ix].connectionpoints.from.number,t) ? netinjection.var_active[devices[ix].connectionpoints.from.number,t] = -fbr_fr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[devices[ix].connectionpoints.from.number,t],-fbr_fr[branch,t])
        !isassigned(netinjection.var_active,devices[ix].connectionpoints.to.number,t) ? netinjection.var_active[devices[ix].connectionpoints.to.number,t] = fbr_to[branch,t] : JuMP.add_to_expression!(netinjection.var_active[devices[ix].connectionpoints.to.number,t],fbr_to[branch,t])

    end

end

function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, devices::Array{D,1}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: CopperPlatePowerModel, D <: PowerSystems.Branch}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:sys.time_periods

    active_fbr_to = @variable(m, active_fbr_to[on_set,time_range])
    active_fbr_fr = @variable(m, active_fbr_fr[on_set,time_range])

    reactive_fbr_to = @variable(m, reactive_fbr_to[on_set,time_range])
    reactive_fbr_fr = @variable(m, reactive_fbr_fr[on_set,time_range])

    for t in time_range, (ix,branch) in enumerate(active_fbr_to.axes[1])

        !isassigned(netinjection.var_active,devices[ix].connectionpoints.from.number,t) ? netinjection.var_active[devices[ix].connectionpoints.from.number,t] = -active_fbr_fr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[devices[ix].connectionpoints.from.number,t],-active_fbr_fr[branch,t])
        !isassigned(netinjection.var_active,devices[ix].connectionpoints.to.number,t) ? netinjection.var_active[devices[ix].connectionpoints.to.number,t] = active_fbr_to[branch,t] : JuMP.add_to_expression!(netinjection.var_active[devices[ix].connectionpoints.to.number,t],-active_fbr_to[branch,t])

        !isassigned(netinjection.var_reactive,devices[ix].connectionpoints.from.number,t) ? netinjection.var_reactive[devices[ix].connectionpoints.from.number,t] = -reactive_fbr_fr[branch,t] : JuMP.add_to_expression!(netinjection.var_reactive[devices[ix].connectionpoints.from.number,t],-reactive_fbr_fr[branch,t])
        !isassigned(netinjection.var_reactive,devices[ix].connectionpoints.to.number,t) ? netinjection.var_reactive[devices[ix].connectionpoints.to.number,t] = reactive_fbr_to[branch,t] : JuMP.add_to_expression!(netinjection.var_reactive[devices[ix].connectionpoints.to.number,t],-reactive_fbr_to[branch,t])


    end

end