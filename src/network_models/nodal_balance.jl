function VarBranchInjection!(VarNetInjection::A, fbr::PowerVariable, branches::Array{B}, time_periods::Int) where {A <: PowerExpressionArray, B <:Branch}

    for t = 1:time_periods, branch in fbr.indexsets[1]

        node_from = [device.connectionpoints.from.number for device in branches if device.name == branch][1]
        node_to =   [device.connectionpoints.to.number for device in branches if device.name == branch][1]

        !isassigned(VarNetInjection,node_from,t) ? VarNetInjection[node_from,t] = -fbr[branch,t]: append!(VarNetInjection[node_from,t],-fbr[branch,t])
        !isassigned(VarNetInjection,node_to,t) ? VarNetInjection[node_to,t] = fbr[branch,t] : append!(VarNetInjection[node_to,t],fbr[branch,t])

    end

    return VarNetInjection
end

function NodalFlowBalance(m::JuMP.Model, VarNetInjection::A, TsInjectionBalance:: Array{Float64}, time_steps::Int64) where  A <: PowerExpressionArray

        # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
        # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])

        @constraintref PFBalance[1:size(VarNetInjection)[1], 1:time_steps::Int64]

        for (n, c) in enumerate(IndexCartesian(), VarNetInjection)

            PFBalance[n[1],n[2]] = @constraint(m, c == TsInjectionBalance[n[1],n[2]])

        end

        JuMP.registercon(m, :NodalPowerBalance, PFBalance)

    return m
end