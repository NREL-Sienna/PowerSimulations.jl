function BranchFlowVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: Branch
    on_set = [d.name for d in devices if d.available == true]
    t = 1:time_steps
    @variable(m, fbr[on_set,t])
    return fbr
end

function FlowConstraints(m::JuMP.Model, fbr::PowerVariable, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen
    (length(fbr.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])
    @constraintref Pmaxth[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    for t in pth.indexsets[2], (ix, name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            Flow_max[ix, t] = @constraint(m, pth[name, t] >= devices[ix].tech.realpowerlimits.min)
        else
            error("Bus name in Array and variable do not match")
        end
    end
    return true
end

function PTDFNetworkModel(m::JuMP.Model, fbr::PowerVariable, NetInjection::Array{JuMP.AffExpr}, time_periods::Int)

    (length(fbr.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])

    @constraintref Pmaxth[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]

    for t = 1:time_periods, branch in fbr.indexsets[1]

        isempty(NetInjection[node_from,t]) ? NetInjection[node_from,t] = -fbr[branch,t]: append!(NetInjection[node_from,t],-fbr[branch,t])
        isempty(NetInjection[node_to,t]) ? NetInjection[node_to,t] = fbr[branch,t] : append!(NetInjection[node_to,t],fbr[branch,t])

    end

    return NetInjection
end