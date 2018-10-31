function copperplatebalance(m::JuMP.Model, netinjection::BalanceNamedTuple, time_periods::Int64)

    devices_netinjection = remove_undef!(netinjection.var_active)
    timeseries_netinjection = sum(netinjection.timeseries_active, dims=1)

    cpn = JuMP.JuMPArray(Array{ConstraintRef}(undef,time_periods), 1:time_periods)

    for t in 1:time_periods
        # TODO: Check is sum() is the best way to do this in terms of speed.
        cpn[t] = @constraint(m, sum(netinjection.var_active[:,t]) == timeseries_netinjection[t])
    end

    JuMP.register_object(m, :CopperPlateBalance, cpn)

    return m
end