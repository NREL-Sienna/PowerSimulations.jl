function networkflow(m::JuMP.Model, sys::PowerSystems.PowerSystem, DeviceNetInjection::A, PTDF::Array{Float64}) where A <: PowerExpressionArray

    fbr = m[:fbr]
    name_index = m[:fbr].indexsets[1]
    time_index = m[:fbr].indexsets[2]

    (length(time_index) != sys.time_periods) ? error("Length of time dimension inconsistent"): true

    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])
    @constraintref branch_flow[1:length(name_index),1:length(time_index)]

    for t in 1:sys.time_periods, (ix,branch) in enumerate(name_index)

        branch_exp = JuMP.AffExpr([fbr[branch,t]], [1.0], RHS[ix,t])

        for bus in 1:size(timeseries_netinjection)[1]

            isassigned(DeviceNetInjection,bus,t) ? append!(branch_exp, -1*PTDF[ix,bus] * DeviceNetInjection[bus,t]) : continue

        end

        branchflow[ix,t] = @constraint(m, branch_exp == 0.0)

    end

    JuMP.registercon(m, :branchflow, branchflow)

    return m
end

