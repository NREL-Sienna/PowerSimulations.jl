const curtailconstraints = PowerSimulations.powerconstraints

function dispatch(m::JuMP.Model, network::Type{N}, devices_netinjection::T, devices::Array{D}, constraints::Array{<:Function}, time_periods::Int64) where {T <: JumpExpressionMatrix, N <: AbstractDCPowerModel, D <: RenewableGen}

    pre, devices_netinjection = activepowervariables(m, devices_netinjection, devices, time_periods)

        for c in constraints

            m = c(m, devices, time_periods)

        end

    return m, devices_netinjection

end


function constructdevice!(category::Type{PowerSystems.RenewableGen}, network::Type{N}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}=[powerconstraints]) where {T <: JumpExpressionMatrix, N <:NetworkModel}

    devices = [d for d in sys.generators.renewable if (d.available == true && !isa(d, RenewableFix))]

    if !isempty(devices)

        dispatch(m, network, devices_netinjection, devices, constraints, sys.time_periods)

    else

        warn("Renewable dispatch variables created without constraints, the problem might be unbounded")

    end

    return m, devices_netinjection

end