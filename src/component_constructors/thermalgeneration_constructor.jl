function constructdevice!(category::Type{PowerSystems.ThermalGen}, network::Type{N}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}=[powerconstraints]) where {T <: JumpExpressionMatrix, N <: NetworkType}

    devices = sys.generators.thermal

    pth, inyection_array = activepowervariables(m, devices_netinjection, devices, sys.time_periods);

        for c in constraints

            m = c(m, devices, sys.time_periods)

        end

    return m, devices_netinjection

end

function constructdevice!(category::Type{PowerSystems.ThermalGen}, network::Type{N}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}=[powerconstraints]) where {T <: JumpExpressionMatrix, N <: NetworkType}

    devices = sys.generators.thermal

    pth, inyection_array = activepowervariables(m, devices_netinjection, devices, sys.time_periods);

    on_thermal, start_thermal, stop_thermal = commitmentvariables(m, devices, sys.time_periods)

    for c in constraints

        m = c(m, devices, sys.time_periods, true)

    end

    return m, devices_netinjection

end
