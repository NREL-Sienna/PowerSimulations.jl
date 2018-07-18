function varnetinjectiterate!(DevicesNetInjection::A, variable::PowerVariable, time_range::UnitRange{Int64}, devices::Array{T}) where {A <: PowerExpressionArray, T <: PowerSystems.Generator}

    for t in time_range, d in devices

        isassigned(devices_netinjection,  d.bus.number,t) ? append!(DevicesNetInjection[d.bus.number,t], variable[d.name, t]): DevicesNetInjection[d.bus.number,t] = variable[d.name, t];

    end

    return DevicesNetInjection

end

function varnetinjectiterate!(DevicesNetInjection::A, variable::PowerVariable, time_range::UnitRange{Int64}, devices::Array{T}) where {A <: PowerExpressionArray, T <: PowerSystems.ElectricLoad}

    for t in time_range, d in devices

        isassigned(devices_netinjection,  d.bus.number,t) ? append!(DevicesNetInjection[d.bus.number,t], -1*variable[d.name, t]): DevicesNetInjection[d.bus.number,t] = -1*variable[d.name, t];

    end

    return DevicesNetInjection

end

function varnetinjectiterate!(DevicesNetInjection::A, variable_in::PowerVariable, variable_out::PowerVariable, time_range::UnitRange{Int64}, devices::Array{T}) where {A <: PowerExpressionArray, T <: PowerSystems.Storage}

        for t in time_range, d in devices

            isassigned(devices_netinjection,  d.bus.number,t) ? append!(DevicesNetInjection[d.bus.number,t], variable_in[d.name,t] - variable_out[d.name,t]): DevicesNetInjection[d.bus.number,t] = variable_in[d.name,t] - variable_out[d.name,t];

        end

    return DevicesNetInjection

end

