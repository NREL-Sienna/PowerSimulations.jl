function copper_plate(ps_m::CanonicalModel, expression::Symbol, bus_count::Int64, time_steps::UnitRange{Int64})

    devices_netinjection = _remove_undef!(ps_m.expressions[expression])

    ps_m.constraints[:CopperPlateBalance] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, time_steps)

    for t in time_steps
        ps_m.constraints[:CopperPlateBalance][t] = JuMP.@constraint(ps_m.JuMPmodel, sum(ps_m.expressions[expression].data[1:bus_count,t]) == 0)
    end

    return

end
