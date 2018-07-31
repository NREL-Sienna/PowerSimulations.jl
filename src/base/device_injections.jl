function varnetinjectiterate!(devices_netinjection:: A, variable::JumpVariable, time_range::UnitRange{Int64}, devices::Array{T}) where {A <: JumpExpressionMatrix, T <: PowerSystems.Generator}

    for t in time_range, d in devices

        isassigned(devices_netinjection,  d.bus.number,t) ? JuMP.add_to_expression!(devices_netinjection[d.bus.number,t], variable[d.name, t]): devices_netinjection[d.bus.number,t] = variable[d.name, t];

    end

    return devices_netinjection

end

function varnetinjectiterate!(devices_netinjection:: A, variable::JumpVariable, time_range::UnitRange{Int64}, devices::Array{T}) where {A <: JumpExpressionMatrix, T <: PowerSystems.ElectricLoad}

    for t in time_range, d in devices

        isassigned(devices_netinjection,  d.bus.number,t) ? JuMP.add_to_expression!(devices_netinjection[d.bus.number,t], -1*variable[d.name, t]): devices_netinjection[d.bus.number,t] = -1*variable[d.name, t];

    end

    return devices_netinjection

end

function varnetinjectiterate!(devices_netinjection:: A, variable_in::JumpVariable, variable_out::JumpVariable, time_range::UnitRange{Int64}, devices::Array{T}) where {A <: JumpExpressionMatrix, T <: PowerSystems.Storage}

        for t in time_range, d in devices

            isassigned(devices_netinjection,  d.bus.number,t) ? JuMP.add_to_expression!(devices_netinjection[d.bus.number,t], variable_in[d.name,t] - variable_out[d.name,t]): devices_netinjection[d.bus.number,t] = variable_in[d.name,t] - variable_out[d.name,t];

        end

    return devices_netinjection

end

