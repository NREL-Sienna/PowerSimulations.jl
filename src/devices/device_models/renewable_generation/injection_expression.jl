function nodal_expression(ps_m::CanonicalModel, devices::Array{R,1}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen, S <: PM.AbstractPowerFormulation}

    for t in time_range, d in devices

        _add_to_expression!(ps_m.expressions[:var_active], d.bus.number, t, d.tech.installedcapacity * values(d.scalingfactor)[t]) 

        _add_to_expression!(ps_m.expressions[:var_reactive], d.bus.number, t, d.tech.installedcapacity * values(d.scalingfactor)[t]*sin(acos(d.tech.powerfactor))) 

    end

    return

end

function nodal_expression(ps_m::CanonicalModel, devices::Array{R,1}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen, S <: PM.AbstractActivePowerFormulation}

    for t in time_range, d in devices

        _add_to_expression!(ps_m.expressions[:var_active], d.bus.number, t, d.tech.installedcapacity * values(d.scalingfactor)[t]) 

    end

    return

end