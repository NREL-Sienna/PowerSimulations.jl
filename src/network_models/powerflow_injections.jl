function varbranchinjection(fbr::PowerVariable, branches::Array{B}, bus_number::Int64, time_periods::Int64) where {B <:PowerSystems.Branch}

    PowerFlowNetInjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(bus_number, time_periods)

    for t in 1:time_periods, (ix,branch) in enumerate(fbr.indexsets[1])

        branches[ix].name == branch ? node_from = branches[ix].connectionpoints.from.number : error("Branch index/name mismatch")
        branches[ix].name == branch ? node_to = branches[ix].connectionpoints.to.number : error("Branch index/name mismatch")

        !isassigned(PowerFlowNetInjection,node_from,t) ? PowerFlowNetInjection[node_from,t] = -fbr[branch,t]: append!(PowerFlowNetInjection[node_from,t],-fbr[branch,t])
        !isassigned(PowerFlowNetInjection,node_to,t) ? PowerFlowNetInjection[node_to,t] = fbr[branch,t] : append!(PowerFlowNetInjection[node_to,t],fbr[branch,t])

    end

    return PowerFlowNetInjection

end