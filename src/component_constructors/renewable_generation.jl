struct Renewable end

const curtailconstraints = PowerSimulations.powerconstraints

function constructdevice(category::Type{Renewable}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}=[powerconstraints]) where T <: PowerExpressionArray

    devices = [d for d in sys.generators.renewable if (d.available == true && !isa(d, RenewableFix))]

    if !isempty(devices)

        pre, devices_netinjection = generationvariables(m, devices_netinjection, devices, sys.time_periods)

        for c in constraints

            m = c(m, devices, sys.time_periods)

        end

    else

        warn("Renewable dispatch variables created without constraints, the problem might be unbounded")

    end

    return m, devices_netinjection

end