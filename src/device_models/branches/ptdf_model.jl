function dc_networkflow(m::JuMP.Model, netinjection::BalanceNamedTuple, PTDF::PTDFArray)

    fbr = m[:fbr]
    name_index = m[:fbr].axes[1]
    time_index = m[:fbr].axes[2]
    nodes = PTDF.axes[2].val
    node_set = 1:length(nodes)

    ts_flow = gemm('N', 'N', PTDF.data, netinjection.timeseries_active)

    remove_undef!(netinjection.var_active)

    branchflow = JuMP.JuMPArray(Array{ConstraintRef}(undef, length(name_index), time_index[end]), name_index, time_index)

    #TODO: Make consistent with the use of AxisArrays. This syntax doesn't exploit it properly
    for t in time_index
        for (ix,branch) in enumerate(name_index)
            branchflow[branch,t] = @constraint(m, fbr[branch,t] == sum(netinjection.var_active[i,t]*PTDF.data[ix,i] for i in node_set) + ts_flow[ix,t])
        end
    end

    JuMP.register_object(m, :branchflow, branchflow)

    return m
end

