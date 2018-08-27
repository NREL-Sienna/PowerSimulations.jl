function nodalflowbalance(m::JuMP.Model, devices_netinjection::AD, network_netinjection::AF, timeseries_netinjection::Array{Float64}, time_periods::Int64) where  {AD <: JumpExpressionMatrix, AF <: JumpExpressionMatrix}

        pf_balance = JuMP.JuMPArray(Array{ConstraintRef}((size(network_netinjection)[1], time_periods)),1:size(network_netinjection)[1], 1:time_periods)

        for (n, c) in enumerate(IndexCartesian(), network_netinjection)

            isassigned(devices_netinjection,n[1],n[2]) ? JuMP.add_to_expression!(c, devices_netinjection[n[1],n[2]]) : c

            pf_balance[n[1],n[2]] = @constraint(m, c == timeseries_netinjection[n])

        end

        JuMP.registercon(m, :nodalpowerbalance, pf_balance)

    return m
end