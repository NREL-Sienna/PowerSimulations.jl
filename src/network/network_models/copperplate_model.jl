function copper_plate(ps_m::CanonicalModel, expression::Symbol, bus_count::Int64, time_range::UnitRange{Int64})

    devices_netinjection = _remove_undef!(ps_m.expressions[expression])

    ps_m.constraints[:CopperPlateBalance] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, time_range)

    for t in time_range
        ps_m.constraints[:CopperPlateBalance][t] = JuMP.@constraint(ps_m.JuMPmodel, sum(ps_m.expressions[expression][1:bus_count,t]) == 0)
    end

    return

end
