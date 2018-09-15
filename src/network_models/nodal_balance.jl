function nodalflowbalance(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem) where {S <: PM.AbstractDCPForm}

    fbr = m[:fbr]
    name_index = m[:fbr].axes[1]
    time_index = m[:fbr].axes[2]

    for t in time_range, (ix,branch) in enumerate(fbr.axes[1])

        !isassigned(netinjection.var_active,sys.branches[ix].connectionpoints.from.number,t) ? netinjection.var_active[sys.branches[ix].connectionpoints.from.number,t] = -fbr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[sys.branches[ix].connectionpoints.from.number,t],-fbr[branch,t])
        !isassigned(netinjection.var_active,sys.branches[ix].connectionpoints.to.number,t) ? netinjection.var_active[sys.branches[ix].connectionpoints.to.number,t] = fbr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[sys.branches[ix].connectionpoints.to.number,t],fbr[branch,t])

    end

    pf_balance = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(sys.buses), sys.time_periods), bus_names, time_index)

        for (n, c) in enumerate(IndexCartesian(), network_netinjection)

            isassigned(devices_netinjection,n[1],n[2]) ? JuMP.add_to_expression!(c, devices_netinjection[n[1],n[2]]) : c

            pf_balance[n[1],n[2]] = @constraint(m, c == timeseries_netinjection[n])

        end

        JuMP.registercon(m, :nodalpowerbalance, pf_balance)

    return m
    
end


