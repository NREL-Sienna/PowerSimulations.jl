
function constructnetwork!(category::Type{CopperPlatePowerModel}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem; kwargs...) where T <: JumpExpressionMatrix

    TsNets = PowerSimulations.timeseries_netinjection(sys);
    m = PowerSimulations.copperplatebalance(m, devices_netinjection,TsNets, sys.time_periods);

    return m

end

function constructnetwork!(category::Type{StandardPTDF}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem; kwargs...) where {F <: Function, T <: JumpExpressionMatrix}

    fl, flow_injections = PowerSimulations.branchflowvariables(m, sys.branches, length(sys.buses), sys.time_periods);
    timeseries_netinjection = PowerSimulations.timeseries_netinjection(sys);

    if !(:ptdf in keys(kwargs)) #check if the KEY PTDF is present

        warn("PTDF not defined, building")
        PTDF,Adj = PowerSystems.buildptdf(sys.branches,sys.buses);

    end

    m = PowerSimulations.networkflow(m, sys, devices_netinjection, PTDF, timeseries_netinjection);

    #= if conditions for the kwargs

    for category in
        model.psmodel = constructdevice(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    =#

    for (n, c) in enumerate(IndexCartesian(),flow_injections)

        isassigned(devices_netinjection,n[1],n[2]) ? JuMP.add_to_expression!(c, devices_netinjection[n[1],n[2]]) : c

    end

    m = PowerSimulations.nodalflowbalance(m, devices_netinjection, flow_injections, timeseries_netinjection, sys.time_periods);

    return m

end

function constructnetwork!(category::Type{DCPlosslessForm}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem; kwargs ...) where T <: JumpExpressionMatrix

    fl, flow_injections = PowerSimulations.branchflowvariables(m, sys.branches, length(sys.buses), sys.time_periods);

    # m = dcpf(m, sys, fl)

    #= if conditions for the kwargs

    for category in
        model.psmodel = constructdevice(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    =#

    for (n, c) in enumerate(IndexCartesian(), flow_injections)

        isassigned(devices_netinjection,n[1],n[2]) ? JuMP.add_to_expression!(c, devices_netinjection[n[1],n[2]]) : c

    end

    m = PowerSimulations.nodalflowbalance(m, devices_netinjection, sys.time_periods);

    return m

end

function constructnetwork!(category::Type{F}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem; kwargs ...) where {F<: PM.StandardACPForm, T <: JumpExpressionMatrix}

    fl, flow_injections = PowerSimulations.branchflowvariables(m, sys.branches, length(sys.buses), sys.time_periods);
    #theta = anglevariables(m, sys.buses, time_periods)
    #voltage = anglevariables(m, sys.buses, time_periods)
    # m = acpf(formualtion, m, sys, fl)

    #= if conditions for the kwargs

    for category in
        model.psmodel = constructdevice(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    =#

    for (n, c) in enumerate(IndexCartesian(), flow_injections)

        isassigned(devices_netinjection,n[1],n[2]) ? JuMP.add_to_expression!(c, devices_netinjection[n[1],n[2]]) : c

    end

    m = PowerSimulations.nodalflowbalance(m, devices_netinjection, sys.time_periods);

    return m

end
