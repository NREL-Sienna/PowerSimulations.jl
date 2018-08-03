function dispatch(m::JuMP.Model, network::Type{N}, devices_netinjection::T, devices::Array{D}, constraints::Array{<:Function}, time_periods::Int64) where {T <: JumpExpressionMatrix, N <: RealNetwork, D <: ThermalGen}

    pth, inyection_array = activepowervariables(m, devices_netinjection, devices, time_periods);

        for c in constraints

            m = c(m, devices, time_periods)

        end

    return m, devices_netinjection

end

function commitment(m::JuMP.Model, network::Type{N}, devices_netinjection::T, devices::Array{D}, constraints::Array{<:Function}, time_periods::Int64) where {T <: JumpExpressionMatrix, N <: RealNetwork, D <: ThermalGen}

    pth, inyection_array = activepowervariables(m, devices_netinjection, devices, time_periods);

    on_thermal, start_thermal, stop_thermal = commitmentvariables(m, devices, time_periods)

    for c in constraints

        m = c(m, devices, time_periods, true)

    end

    return m, devices_netinjection

end

function constructdevice!(category::Type{PowerSystems.ThermalGen}, network::Type{N}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem, constraints::Array{<:Function}=[powerconstraints]) where {T <: JumpExpressionMatrix, N <: NetworkType}

    if commitmentconstraints in constraints

        m, devices_netinjection = commitment(m, network, devices_netinjection, sys.generators.thermal, constraints, sys.time_periods)

    else

        m, devices_netinjection = dispatch(m, network, devices_netinjection, sys.generators.thermal, constraints, sys.time_periods)

    end

    return m, devices_netinjection
end
