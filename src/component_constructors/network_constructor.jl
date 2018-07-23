struct Network end

function copperplate(m::JuMP.Model,  devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}=[]) where T <: PowerExpressionArray

    TsNets = PowerSimulations.timeseries_netinjection(sys);

    m = PowerSimulations.copperplatebalance(m, devices_netinjection, TsNets, sys.time_periods);
    
    return m, TsNets

end

function dcopf(m::JuMP.Model,  devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}) where T <: PowerExpressionArray

    TsNets = PowerSimulations.timeseries_netinjection(sys)

    fl, PFNets = PowerSimulations.branchflowvariables(m, sys.branches, length(sys.buses), sys.time_periods);

    m = PowerSimulations.nodalflowbalance(m, devices_netinjection, PFNets, TsNets, sys.time_periods);

    m = PowerSimulations.networkflow(m, sys, devices_netinjection, TsNets);


    filter!(e->e≠dcopf,constraints)

    for c in constraints

        m = c(m, sys.branches, sys.time_periods);

    end

    return m, TsNets, PFNets

end


function constructnetwork(m::JuMP.Model,  devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}=[copperplate]) where T <: PowerExpressionArray

    if copperplate in constraints

        m, TsNets = copperplate(m, devices_netinjection, sys, constraints);

        PFNets = [];

    elseif dcopf in constraints
    
        m, TsNets, PFNets = dcopf(m, devices_netinjection, sys, constraints);

    end

    return m, TsNets, PFNets

end