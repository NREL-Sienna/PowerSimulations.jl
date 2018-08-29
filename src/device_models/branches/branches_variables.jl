function branchflowvariables(m::JuMP.Model, devices::Array{T,1}, bus_number::Int64, time_periods::Int64) where T <: PowerSystems.Branch

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:time_periods

    fbr = @variable(m, fbr[on_set,time_range])

    network_netinjection =  JumpAffineExpressionArray(bus_number, time_periods::Int64)

    for t in time_range, (ix,branch) in enumerate(fbr.axes[1])

        !isassigned(network_netinjection,devices[ix].connectionpoints.from.number,t) ? network_netinjection[devices[ix].connectionpoints.from.number,t] = -fbr[branch,t] : JuMP.add_to_expression!(network_netinjection[devices[ix].connectionpoints.from.number,t],-fbr[branch,t])
        !isassigned(network_netinjection,devices[ix].connectionpoints.to.number,t) ? network_netinjection[devices[ix].connectionpoints.to.number,t] = fbr[branch,t] : JuMP.add_to_expression!(network_netinjection[devices[ix].connectionpoints.to.number,t],fbr[branch,t])

    end

    return fbr, network_netinjection
end