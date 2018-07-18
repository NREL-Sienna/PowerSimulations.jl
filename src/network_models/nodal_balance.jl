function nodalflowbalance(m::JuMP.Model, devices_netinjection::AD, network_netinjection::AF, timeseries_netinjection::Array{Float64}, time_periods::Int64) where  {AD <: PowerExpressionArray, AF <: PowerExpressionArray}

        # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
        # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])

        @constraintref pf_balance[1:size(network_netinjection)[1], 1:time_periods::Int64]

        for (n, c) in enumerate(IndexCartesian(), network_netinjection)

            isassigned(devices_netinjection,n[1],n[2]) ? append!(c, devices_netinjection[n[1],n[2]]) : c

            pf_balance[n[1],n[2]] = @constraint(m, c == timeseries_netinjection[n[1],n[2]])

        end

        JuMP.registercon(m, :nodalpowerbalance, pf_balance)

    return m
end