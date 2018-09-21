function dc_networkflow(m::JuMP.Model, netinjection::BalanceNamedTuple, PTDF::PTDFArray) 

    fbr = m[:fbr]
    name_index = m[:fbr].axes[1]
    time_index = m[:fbr].axes[2]

    #Add Multiplication of PTDF*Time_series Injections

    branchflow = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(name_index), time_index), name_index, time_index)

    for t in time_index, (ix,branch) in enumerate(name_index)

        #find efficient way to create affine expressions in JuMP v0.18 
        # example: Expression(Fbr[branch,:], PTDF[branch,:])
        branch_exp = JuMP.AffExpr(1.0,Dict(fbr[branch,t]=>1.0)) 

        for bus in 1:size(timeseries_netinjection)[1]

            isassigned(DeviceNetInjection,bus,t) ? JuMP.add_to_expression!(branch_exp, -1*PTDF[ix,bus] * DeviceNetInjection[bus,t]) : continue

        end

        branchflow[branch,t] = @constraint(m, branch_exp == 0.0)

    end

    JuMP.registercon(m, :branchflow, branchflow)

    return m
end

