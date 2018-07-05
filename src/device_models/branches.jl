function BranchFlowVariables(m::JuMP.Model, devices::Array{T,1}, time_periods) where T <: Branch
    on_set = [d.name for d in devices if d.available == true]
    t = 1:time_periods
    @variable(m, fbr[on_set,t])
    return fbr
end

# TODO: Add the Flow limits for a DC Line
# TODO: Add the Flow limits for a Transformer

function FlowConstraints(m::JuMP.Model, fbr::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: Branch
    (length(fbr.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true

    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])
    @constraintref Flow_max_tf[1:length(fbr.indexsets[1]),1:length(fbr.indexsets[2])]
    @constraintref Flow_max_ft[1:length(fbr.indexsets[1]),1:length(fbr.indexsets[2])]
    for t in fbr.indexsets[2], (ix, name) in enumerate(fbr.indexsets[1])
        if name == devices[ix].name
            Flow_max_tf[ix, t] = @constraint(m, fbr[name, t] <= devices[ix].rate.to_from)
            Flow_max_ft[ix, t] = @constraint(m, fbr[name, t] >= -1*devices[ix].rate.from_to)
        else
            error("Branch name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :Flow_max_ToFrom, Flow_max_tf)
    JuMP.registercon(m, :Flow_max_FromTo, Flow_max_ft)

    return m
end

function PTDFNetworkModel(m::JuMP.Model, sys::PowerSystems.PowerSystem, fbr::PowerVariable, NetInjection::A, time_periods::Int64) where A <: PowerExpressionArray

    (length(fbr.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true

    PTDF, A = PowerSystems.BuildPTDF(sys.branches, sys.buses)

    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])
    @constraintref BranchFlow[1:length(fbr.indexsets[1]),1:length(fbr.indexsets[2])]

    for t = 1:time_periods, branch in fbr.indexsets[1]

    end

    JuMP.registercon(m, :BranchFlow, BranchFlow)

    return m
end