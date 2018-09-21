function dc_networkflow(m::JuMP.Model, netinjection::BalanceNamedTuple, sys::PowerSystems.PowerSystem, PTDF::Array{Float64}) 

    fbr = m[:fbr]
    name_index = m[:fbr].axes[1]
    time_index = m[:fbr].axes[2]

    (length(time_index) != sys.time_periods) ? error("Length of time dimension inconsistent") : true

    branchflow = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(name_index), sys.time_periods), name_index, time_index)

    for t in 1:sys.time_periods, (ix,branch) in enumerate(name_index)

        branch_exp = JuMP.AffExpr(1.0,Dict(fbr[branch,t]=>1.0)) #This is not working

        for bus in 1:size(timeseries_netinjection)[1]

            isassigned(DeviceNetInjection,bus,t) ? JuMP.add_to_expression!(branch_exp, -1*PTDF[ix,bus] * DeviceNetInjection[bus,t]) : continue

        end

        branchflow[branch,t] = @constraint(m, branch_exp == 0.0)

    end

    JuMP.registercon(m, :branchflow, branchflow)

    return m
end

