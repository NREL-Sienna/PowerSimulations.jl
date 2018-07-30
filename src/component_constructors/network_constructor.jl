
function constructnetwork(category::Type{CopperPlate}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem; kwargs...) where T <: PowerExpressionArray

    m = PowerSimulations.copperplatebalance(m, devices_netinjection, sys.time_periods);

    return m

end

function constructnetwork(category::Type{NetworkFlow}, branches::Array{@NT(device::DataType,constraints::F)}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem; kwargs...) where {F <: Function, T <: PowerExpressionArray}

    fl, flow_injections = PowerSimulations.branchflowvariables(m, sys.branches, length(sys.buses), sys.time_periods);

    if :ptdf in keys(kwargs) #check if the KEY PTDF is present

        m = networkflow(m, sys, devices_netinjection, PTDF);

    else
        error("No PTDF")
    end

    #= if conditions for the kwargs

    for category in
        model.psmodel = constructdevice(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    =#

    for (n, c) in enumerate(IndexCartesian(), flow_netinjections)

        isassigned(devices_netinjection,n[1],n[2]) ? append!(c, devices_netinjection[n[1],n[2]]) : c

    end

    m = PowerSimulations.nodalflowbalance(m, devices_netinjection, sys.time_periods);

    return m

end

function constructnetwork(category::Type{DCPowerFlow}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem; kwargs ...) where T <: PowerExpressionArray

    fl, flow_injections = PowerSimulations.branchflowvariables(m, sys.branches, length(sys.buses), sys.time_periods);

    # m = dcpf(m, sys, fl)

    #= if conditions for the kwargs

    for category in
        model.psmodel = constructdevice(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    =#

    for (n, c) in enumerate(IndexCartesian(), flow_netinjections)

        isassigned(devices_netinjection,n[1],n[2]) ? append!(c, devices_netinjection[n[1],n[2]]) : c

    end

    m = PowerSimulations.nodalflowbalance(m, devices_netinjection, sys.time_periods);

    return m

end

function constructnetwork(category::Type{F}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem; kwargs ...) where {F<: ACPowerFlow, T <: PowerExpressionArray}

    fl, flow_injections = PowerSimulations.branchflowvariables(m, sys.branches, length(sys.buses), sys.time_periods);
    #theta = anglevariables(m, sys.buses, time_periods)
    #voltage = anglevariables(m, sys.buses, time_periods)
    # m = acpf(formualtion, m, sys, fl)

    #= if conditions for the kwargs

    for category in
        model.psmodel = constructdevice(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    =#

    for (n, c) in enumerate(IndexCartesian(), flow_netinjections)

        isassigned(devices_netinjection,n[1],n[2]) ? append!(c, devices_netinjection[n[1],n[2]]) : c

    end

    m = PowerSimulations.nodalflowbalance(m, devices_netinjection, sys.time_periods);

    return m

end
