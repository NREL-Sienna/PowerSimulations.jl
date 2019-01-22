function add_flows(m::JuMP.AbstractModel, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PSY.PowerSystem) where {S <: PM.AbstractDCPForm}

    fbr = m[:fbr]
    branch_name_index = m[:fbr].axes[1]
    time_index = m[:fbr].axes[2]

    for t in time_index, (ix,branch) in enumerate(branch_name_index)

        !isassigned(netinjection.var_active,sys.branches[ix].connectionpoints.from.number,t) ? netinjection.var_active[sys.branches[ix].connectionpoints.from.number,t] = -fbr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[sys.branches[ix].connectionpoints.from.number,t],-fbr[branch,t])
        !isassigned(netinjection.var_active,sys.branches[ix].connectionpoints.to.number,t) ? netinjection.var_active[sys.branches[ix].connectionpoints.to.number,t] = fbr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[sys.branches[ix].connectionpoints.to.number,t],fbr[branch,t])

    end


end

function add_flows(m::JuMP.AbstractModel, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PSY.PowerSystem) where {S <: PM.AbstractDCPLLForm}

    fbr_fr = m[:fbr_fr]
    fbr_to = m[:fbr_to]
    time_index = m[:fbr_to].axes[2]
    branch_name_index = m[:fbr_fr].axes[1]

    for t in time_index, (ix,branch) in enumerate(branch_name_index)

        !isassigned(netinjection.var_active,sys.branches[ix].connectionpoints.from.number,t) ? netinjection.var_active[sys.branches[ix].connectionpoints.from.number,t] = -fbr_fr[branch,t] : JuMP.add_to_expression!(netinjection.var_active[sys.branches[ix].connectionpoints.from.number,t],-fbr_fr[branch,t])
        !isassigned(netinjection.var_active,sys.branches[ix].connectionpoints.to.number,t) ? netinjection.var_active[sys.branches[ix].connectionpoints.to.number,t] = fbr_to[branch,t] : JuMP.add_to_expression!(netinjection.var_active[sys.branches[ix].connectionpoints.to.number,t],fbr_to[branch,t])

    end

end

function nodalflowbalance(m::JuMP.AbstractModel, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PSY.PowerSystem) where {S <: StandardPTDFModel}

    time_index = 1:sys.time_periods
    bus_name_index = [b.name for b in sys.buses]

    add_flows(m, netinjection, system_formulation, sys)

    pf_balance = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef,length(bus_name_index), sys.time_periods), bus_name_index, time_index)

        for t in time_index, (ix,bus) in enumerate(bus_name_index)

            isassigned(netinjection.var_active,ix, t) ? true : @error "Islanded Bus in the system"

            pf_balance[bus,t] = JuMP.@constraint(m, netinjection.var_active[ix, t] == netinjection.timeseries_active[ix, t])

        end

        JuMP.register_object(m, :NodalFlowBalance_active, pf_balance)

end


function nodalflowbalance(m::JuMP.AbstractModel, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PSY.PowerSystem) where {S <: PM.AbstractActivePowerFormulation}

    time_index = 1:sys.time_periods
    bus_name_index = [b.name for b in sys.buses]

    PM_dict = pass_to_pm(sys, netinjection)

        for t in time_index, bus in sys.buses

            !isassigned(netinjection.var_active,bus.number,t) ? PM_dict["nw"]["$(t)"]["bus"]["$(bus.number)"]["pni"] = -(netinjection.timeseries_active[bus.number, t]) : PM_dict["nw"]["$(t)"]["bus"]["$(bus.number)"]["pni"] = JuMP.add_to_expression!(netinjection.var_active[bus.number,t],-(netinjection.timeseries_active[bus.number, t]))

        end

        m.ext[:PM_object] = PM_dict

end

function nodalflowbalance(m::JuMP.AbstractModel, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PSY.PowerSystem) where {S <: PM.AbstractPowerFormulation}

    nodalflowbalance(m, netinjection, PM.AbstractActivePowerFormulation, sys)

    PM_dict = m.ext[:PM_object]

    time_index = 1:sys.time_periods
    bus_name_index = [b.name for b in sys.buses]

        for t in time_index, bus in sys.buses

            !isassigned(netinjection.var_reactive,bus.number,t) ? PM_dict["nw"]["$(t)"]["bus"]["$(bus.number)"]["qni"] = -(netinjection.timeseries_reactive[bus.number, t]) : PM_dict["nw"]["$(t)"]["bus"]["$(bus.number)"]["qni"] = JuMP.add_to_expression!(netinjection.var_reactive[bus.number,t],-(netinjection.timeseries_reactive[bus.number, t]))

        end

        m.ext[:PM_object] = PM_dict

end