function nodalflowbalance(m::JuMP.Model, DeviceNetInjection::AD, PowerFlowNetInjection::AF, timeseries_netinjection::Array{Float64}, time_periods::Int64) where  {AD <: PowerExpressionArray, AF <: PowerExpressionArray}

        # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
        # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])

        @constraintref PFBalance[1:size(PowerFlowNetInjection)[1], 1:time_periods::Int64]

        for (n, c) in enumerate(IndexCartesian(), PowerFlowNetInjection)

            isassigned(DeviceNetInjection,n[1],n[2]) ? append!(c, DeviceNetInjection[n[1],n[2]]) : c

            PFBalance[n[1],n[2]] = @constraint(m, c == timeseries_netinjection[n[1],n[2]])

        end

        JuMP.registercon(m, :NodalPowerBalance, PFBalance)

    return m
end