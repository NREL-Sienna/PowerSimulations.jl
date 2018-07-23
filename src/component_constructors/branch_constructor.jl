struct NetworkFlow end
struct DCpowerflow end
struct ACPowerFlow end

function constructdevice(category::Type{NetworkFlow}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}=[flowconstraints]) where T <: PowerExpressionArray


    fl, flow_injections = PowerSimulations.branchflowvariables(m, sys.branches, length(sys.buses), sys.time_periods);

    #Split the network flow construction step to avoid having to pass the time_series input. Add the TimeSeries step to the nodal flow balance construction step.

    m = networkflow(m, sys, devices_netinjection)

    for (n, c) in enumerate(IndexCartesian(), flow_netinjections)

        isassigned(devices_netinjection,n[1],n[2]) ? append!(c, devices_netinjection[n[1],n[2]]) : c

    end

    return m, devices_netinjection

end