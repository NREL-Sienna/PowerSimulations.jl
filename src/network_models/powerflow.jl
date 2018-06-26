function PowerFlowBalance(m::JuMP.Model, NetInjection::Array{JuMP.AffExpr}, fbr::PowerVariable, branches::Array{Branch}, tp::Int)

    for branch in fbr.indexsets[1]
        node_from = [device.connectionpoints.from.number for device in branches if device.name == branch][1]
        node_to =   [device.connectionpoints.to.number for device in branches if device.name == branch][1]

            for t = 1:tp

            isempty(NetInjection[node_from,t]) ? NetInjection[node_from,t] = -fbr[branch,t]: append!(NetInjection[node_from,t],-fbr[branch,t])
            isempty(NetInjection[node_to,t]) ? NetInjection[node_to,t] = fbr[branch,t] : append!(NetInjection[node_to,t],fbr[branch,t])

            end

    end

    return NetInjection
end