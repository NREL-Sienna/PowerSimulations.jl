struct Renewable end

const curtailconstraints = PowerSimulations.powerconstraints

function constructdevice(device::Type{Renewable}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Union{Nothing,Array{<:Function}}) where T <: PowerExpressionArray

    devices = [d for d in sys.generators.renewable if (d.available == true && !isa(d, RenewableFix))]

    if !isempty(devices)

        pre, devices_netinjection = generationvariables(m, devices_netinjection, devices, sys.time_periods)

        if !isa(constraints,Nothing)

            for c in constraints

                # TODO: Find a smarter way to pass on the variables, or rewrite to pass just m and call the variable from inside the function.

                m = c(m, pre, devices, sys.time_periods)

            end

        else

            warn("Renewable dispatch variables created without constraints, the problem might be unbounded")

        end

    end

    return m, devices_netinjection

end