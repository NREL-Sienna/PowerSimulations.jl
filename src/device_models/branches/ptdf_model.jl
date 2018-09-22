function dc_networkflow(m::JuMP.Model, netinjection::BalanceNamedTuple, PTDF::PTDFArray)

    fbr = m[:fbr]
    name_index = m[:fbr].axes[1]
    time_index = m[:fbr].axes[2]

    ts_flow = gemm('N', 'N', PTDF.data, netinjection.timeseries_active)

    branchflow = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(name_index), time_index), name_index, time_index)

    for t in time_index
        for branch in name_index
            branchflow[branch,t] = @constraint(m, fbr[branch,t] == sum(netinjection.var_active[i,t]*PTDF[branch,i] for i in PTDF.axes[1].val) + ts_flow[branch,t])
        end
    end

    JuMP.registercon(m, :branchflow, branchflow)

    return m
end

