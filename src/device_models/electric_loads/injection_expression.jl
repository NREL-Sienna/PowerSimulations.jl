function nodal_expression(ps_m::CanonicalModel, devices::Array{L,1}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {L <: PSY.PowerLoad, S <: PM.AbstractPowerFormulation}

    for t in time_range, d in devices

        _add_to_expression!(ps_m.expressions["var_active"], d.bus.number, t, -1*d.maxactivepower * values(d.scalingfactor)[t]) 

        _add_to_expression!(ps_m.expressions["var_reactive"], d.bus.number, t, -1*d.maxreactivepower*values(d.scalingfactor)[t]) 

    end


end

function nodal_expression(ps_m::CanonicalModel, devices::Array{L,1}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {L <: PSY.PowerLoad, S <: PM.AbstractActivePowerFormulation}

    for t in time_range, d in devices

        _add_to_expression!(ps_m.expressions["var_active"], d.bus.number, t, -1*d.maxactivepower * values(d.scalingfactor)[t]) 

    end


end