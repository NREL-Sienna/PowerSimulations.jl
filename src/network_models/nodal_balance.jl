function add_flows(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem) where {S <: PM.AbstractDCPForm}

    fbr = m[:fbr]
    branch_name_index = m[:fbr].axes[1]
    time_index = m[:fbr].axes[2]

    for t in time_index, (ix,branch) in enumerate(branch_name_index)

        !isassigned(netinjection.var_active,sys.branches[ix].connectionpoints.from.number,t) ? netinjection.var_active[sys.branches[ix].connectionpoints.from.number,t] = -fbr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[sys.branches[ix].connectionpoints.from.number,t],-fbr[branch,t])
        !isassigned(netinjection.var_active,sys.branches[ix].connectionpoints.to.number,t) ? netinjection.var_active[sys.branches[ix].connectionpoints.to.number,t] = fbr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[sys.branches[ix].connectionpoints.to.number,t],fbr[branch,t])

    end


end

function add_flows(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem) where {S <: PM.AbstractDCPLLForm}

    fbr_fr = m[:fbr_fr]
    fbr_to = m[:fbr_to]
    time_index = m[:fbr_to].axes[2]
    branch_name_index = m[:fbr_fr].axes[1]

    for t in time_index, (ix,branch) in enumerate(branch_name_index)

        !isassigned(netinjection.var_active,sys.branches[ix].connectionpoints.from.number,t) ? netinjection.var_active[sys.branches[ix].connectionpoints.from.number,t] = -fbr_fr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[sys.branches[ix].connectionpoints.from.number,t],-fbr_fr[branch,t])
        !isassigned(netinjection.var_active,sys.branches[ix].connectionpoints.to.number,t) ? netinjection.var_active[sys.branches[ix].connectionpoints.to.number,t] = fbr_to[branch,t] : JuMP.add_to_expression!(netinjection.var_active[sys.branches[ix].connectionpoints.to.number,t],fbr_to[branch,t])

    end


end

function nodalflowbalance(m::JuMP.Model, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem) where {S <: AbstractDCPowerModel}

    time_index = 1:sys.time_periods
    bus_name_index = [b.name for b in sys.buses]

    add_flows(m, netinjection, system_formulation, sys)

    pf_balance = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(bus_name_index), sys.time_periods), bus_name_index, time_index)

        for t in time_index, (ix,bus) in enumerate(bus_name_index)

            isassigned(netinjection.var_active,ix, t) ? true : @error("Islanded Bus in the system")

            pf_balance[bus,t] = @constraint(m, netinjection.var_active[ix, t] == netinjection.timeseries_active[ix, t])
        
        end

        JuMP.registercon(m, :NodalFlowBalance, pf_balance)

    return m
    
end
