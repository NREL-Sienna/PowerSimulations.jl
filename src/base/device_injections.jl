function varnetinjectiterate!(devices_netinjection:: A, variable::PowerVariable, time_range::UnitRange{Int64}, devices::Array{T}) where {A <: PowerExpressionArray, T <: PowerSystems.Generator}

    for t in time_range, d in devices

        isassigned(devices_netinjection,  d.bus.number,t) ? append!(devices_netinjection[d.bus.number,t], variable[d.name, t]): devices_netinjection[d.bus.number,t] = variable[d.name, t];

    end

    return devices_netinjection

end

function varnetinjectiterate!(devices_netinjection:: A, variable::PowerVariable, time_range::UnitRange{Int64}, devices::Array{T}) where {A <: PowerExpressionArray, T <: PowerSystems.ElectricLoad}

    for t in time_range, d in devices

        isassigned(devices_netinjection,  d.bus.number,t) ? append!(devices_netinjection[d.bus.number,t], -1*variable[d.name, t]): devices_netinjection[d.bus.number,t] = -1*variable[d.name, t];

    end

    return devices_netinjection

end

function varnetinjectiterate!(devices_netinjection:: A, variable_in::PowerVariable, variable_out::PowerVariable, time_range::UnitRange{Int64}, devices::Array{T}) where {A <: PowerExpressionArray, T <: PowerSystems.Storage}

        for t in time_range, d in devices

            isassigned(devices_netinjection,  d.bus.number,t) ? append!(devices_netinjection[d.bus.number,t], variable_in[d.name,t] - variable_out[d.name,t]): devices_netinjection[d.bus.number,t] = variable_in[d.name,t] - variable_out[d.name,t];

        end

    return devices_netinjection

end

