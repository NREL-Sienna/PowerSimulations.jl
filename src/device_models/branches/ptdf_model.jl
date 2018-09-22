function dc_networkflow(m::JuMP.Model, netinjection::BalanceNamedTuple, PTDF::PTDFArray)

    fbr = m[:fbr]
    name_index = m[:fbr].axes[1]
    time_index = m[:fbr].axes[2]

    #Add Multiplication of PTDF*Time_series Injections

    branchflow = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(name_index), time_index), name_index, time_index)

    for t in time_index
        for branch in name_index
            branchflow[branch,t] = @constraint(m, sum(netinjection.var_active[i,t]*PTDF[branch,i] for i in PTDF.axes[1].val) == net_load[b,t])
        end
    end

    JuMP.registercon(m, :branchflow, branchflow)

    return m
end

