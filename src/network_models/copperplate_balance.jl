function copperplatebalance(m::JuMP.Model, devices_netinjection::A, timeseries_netinjection:: Array{Float64}, time_periods::Int64) where A <: JumpExpressionMatrix

    devices_netinjection = remove_undef!(devices_netinjection)
    timeseries_netinjection = sum(timeseries_netinjection, 1)

    cpn = JuMP.JuMPArray(Array{ConstraintRef}(time_periods), 1:time_periods)

    for t in 1:time_periods
        # TODO: Check is sum() is the best way to do this. Update in JuMP 0.19 to JuMP.add_to_expression!()
        cpn[t] = @constraint(m, sum(devices_netinjection[:,t]) == timeseries_netinjection[t])
    end

    JuMP.registercon(m, :CopperPlateBalance, cpn)

    return m
end