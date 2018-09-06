function constructdevice!(category::Type{PowerSystems.ThermalGen}, network::Type{N}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}=[powerconstraints]) where {T <: JumpExpressionMatrix, N <: NetworkType}

    pth, inyection_array = activepowervariables(m, devices_netinjection, devices, time_periods);

        for c in constraints

            m = c(m, devices, time_periods)

        end

    return m, devices_netinjection

end

function constructdevice!(category::Type{PowerSystems.ThermalGen}, network::Type{N}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}=[powerconstraints]) where {T <: JumpExpressionMatrix, N <: NetworkType}

    pth, inyection_array = activepowervariables(m, devices_netinjection, devices, time_periods);

    on_thermal, start_thermal, stop_thermal = commitmentvariables(m, devices, time_periods)

    for c in constraints

        m = c(m, devices, time_periods, true)

    end

    return m, devices_netinjection

end
