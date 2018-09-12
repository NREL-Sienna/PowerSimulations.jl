function constructnetwork!(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, devices::Array{D,1}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: CopperPlatePowerModel, D <: PowerSystems.Branch}

end

function constructnetwork!(m::JuMP.Model, system_formulation::Type{S}, devices::Array{D,1}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: AbstractDCPowerModel, D <: PowerSystems.Branch}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:sys.time_periods

    fbr = @variable(m, fbr[on_set,time_range])

    network_netinjection =  JumpAffineExpressionArray(undef,length(sys.buses), sys.time_periods)

    for t in time_range, (ix,branch) in enumerate(fbr.axes[1])

        !isassigned(network_netinjection,devices[ix].connectionpoints.from.number,t) ? network_netinjection[devices[ix].connectionpoints.from.number,t] = -fbr[branch,t] : JuMP.add_to_expression!(network_netinjection[devices[ix].connectionpoints.from.number,t],-fbr[branch,t])
        !isassigned(network_netinjection,devices[ix].connectionpoints.to.number,t) ? network_netinjection[devices[ix].connectionpoints.to.number,t] = fbr[branch,t] : JuMP.add_to_expression!(network_netinjection[devices[ix].connectionpoints.to.number,t],fbr[branch,t])

    end

end


function constructnetwork!(m::JuMP.Model, system_formulation::Type{S}, devices::Array{D,1}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: AbstractACPowerModel, D <: PowerSystems.Branch}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:sys.time_periods

    fbr_to = @variable(m, fbr_to[on_set,time_range])
    fbr_fr = @variable(m, fbr_fr[on_set,time_range])

    network_netinjection =  JumpAffineExpressionArray(undef,length(sys.buses), sys.time_periods)

    for t in time_range, (ix,branch) in enumerate(fbr_to.axes[1])

        !isassigned(network_netinjection,devices[ix].connectionpoints.from.number,t) ? network_netinjection[devices[ix].connectionpoints.from.number,t] = -fbr[branch,t] : JuMP.add_to_expression!(network_netinjection[devices[ix].connectionpoints.from.number,t],-fbr[branch,t])
        !isassigned(network_netinjection,devices[ix].connectionpoints.from.number,t) ? network_netinjection[devices[ix].connectionpoints.from.number,t] = -fbr[branch,t] : JuMP.add_to_expression!(network_netinjection[devices[ix].connectionpoints.from.number,t],-fbr[branch,t])
    end

end

function constructnetwork!(m::JuMP.Model, system_formulation::Type{S}, devices::Array{D,1}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: AbstractACPowerModel, D <: PowerSystems.Branch}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:sys.time_periods

    active_fbr_to = @variable(m, fbr_to[on_set,time_range])
    active_fbr_fr = @variable(m, fbr_fr[on_set,time_range])

    reactive_fbr_to = @variable(m, fbr_to[on_set,time_range])
    reactive_fbr_fr = @variable(m, fbr_fr[on_set,time_range])

    network_netinjection =  JumpAffineExpressionArray(undef,length(sys.buses), sys.time_periods)

    for t in time_range, (ix,branch) in enumerate(fbr_to.axes[1])

        !isassigned(network_netinjection,devices[ix].connectionpoints.from.number,t) ? network_netinjection[devices[ix].connectionpoints.from.number,t] = -fbr[branch,t] : JuMP.add_to_expression!(network_netinjection[devices[ix].connectionpoints.from.number,t],-fbr[branch,t])
        !isassigned(network_netinjection,devices[ix].connectionpoints.from.number,t) ? network_netinjection[devices[ix].connectionpoints.from.number,t] = -fbr[branch,t] : JuMP.add_to_expression!(network_netinjection[devices[ix].connectionpoints.from.number,t],-fbr[branch,t])
    end

end