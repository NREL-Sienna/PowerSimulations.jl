function branchflowvariables(m::JuMP.Model, devices::Array{T,1}, bus_number::Int64, time_periods::Int64) where T <: PowerSystems.Branch

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:time_periods

    fbr = @variable(m, fbr[on_set,time_range])

    PowerFlowNetInjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(bus_number, time_periods)

    for t in time_range, (ix,branch) in enumerate(fbr.indexsets[1])

        !isassigned(PowerFlowNetInjection,devices[ix].connectionpoints.from.number,t) ? PowerFlowNetInjection[devices[ix].connectionpoints.from.number,t] = -fbr[branch,t]: append!(PowerFlowNetInjection[devices[ix].connectionpoints.from.number,t],-fbr[branch,t])
        !isassigned(PowerFlowNetInjection,devices[ix].connectionpoints.to.number,t) ? PowerFlowNetInjection[devices[ix].connectionpoints.to.number,t] = fbr[branch,t] : append!(PowerFlowNetInjection[devices[ix].connectionpoints.to.number,t],fbr[branch,t])

    end

    return fbr, PowerFlowNetInjection
end

function flowconstraints(m::JuMP.Model, fbr::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.Branch
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


function ptdf_powerflow(m::JuMP.Model, sys::PowerSystems.PowerSystem, fbr::PowerVariable, DeviceNetInjection::A, TsInjectionBalance::Array{Float64}) where A <: PowerExpressionArray

    (length(fbr.indexsets[2]) != sys.time_periods) ? error("Length of time dimension inconsistent"): true

    PTDF, = PowerSystems.build_ptdf(sys.branches, sys.buses)
    RHS = BLAS.gemm('N','N', PTDF, TsInjectionBalance)

    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])
    @constraintref branch_flow[1:length(fbr.indexsets[1]),1:length(fbr.indexsets[2])]

    for t in 1:sys.time_periods, (ix,branch) in enumerate(fbr.indexsets[1])

        branch_exp = JuMP.AffExpr([fbr[branch,t]], [1.0], RHS[ix,t])

        for bus in 1:size(TsInjectionBalance)[1]

            append!(branch_exp, -1*PTDF[ix,bus] * DeviceNetInjection[bus,t])

        end

        branch_flow[ix,t] = @constraint(m, branch_exp == 0.0)

    end

    JuMP.registercon(m, :BranchFlow, branch_flow)

    return m
end

