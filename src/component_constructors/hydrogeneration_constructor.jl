struct Hydro end

const curtailconstraints = PowerSimulations.powerconstraints

function constructdevice!(category::Type{Hydro}, transmission::Type{CopperPlatePowerModel}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}=[powerconstraints]) where T <: JumpExpressionMatrix

    devices = [d for d in sys.generators.hydro if (d.available == true && !isa(d, HydroFix))]

    if !isempty(devices)

        pre, devices_netinjection = activepowervariables(m, devices_netinjection, devices, sys.time_periods)

        for c in constraints

            m = c(m, devices, sys.time_periods)

        end

    else

        warn("Hydro dispatch variables created without constraints, the problem might be unbounded")

    end

    return m, devices_netinjection

end