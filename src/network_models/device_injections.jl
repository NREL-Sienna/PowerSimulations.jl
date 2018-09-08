function varnetinjectiterate!(netinjection::A, variable::JumpVariable, time_periods::Int64, devices::Array{T}) where {A <: JumpExpressionMatrix, T <: PowerSystems.Generator}

    for t in 1:time_periods, d in devices

        isassigned(netinjection,  d.bus.number,t) ? JuMP.add_to_expression!(netinjection[d.bus.number,t], variable[d.name, t]) : netinjection[d.bus.number,t] = variable[d.name, t];

    end

    return netinjection

end

function varnetinjectiterate!(netinjection::A, variable::JumpVariable, time_range::UnitRange{Int64}, devices::Array{T}) where {A <: JumpExpressionMatrix, T <: PowerSystems.ElectricLoad}

    for t in time_range, d in devices

        isassigned(netinjection,  d.bus.number,t) ? JuMP.add_to_expression!(netinjection[d.bus.number,t], -1*variable[d.name, t]) : netinjection[d.bus.number,t] = -1*variable[d.name, t];

    end

    return netinjection

end

function varnetinjectiterate!(netinjection::A, variable_in::JumpVariable, variable_out::JumpVariable, time_range::UnitRange{Int64}, devices::Array{T}) where {A <: JumpExpressionMatrix, T <: PowerSystems.Storage}

        for t in time_range, d in devices

            isassigned(netinjection,  d.bus.number,t) ? JuMP.add_to_expression!(netinjection[d.bus.number,t], variable_in[d.name,t] - variable_out[d.name,t]) : netinjection[d.bus.number,t] = variable_in[d.name,t] - variable_out[d.name,t];

        end

    return netinjection

end

