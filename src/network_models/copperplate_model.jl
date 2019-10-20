function copper_plate(canonical::CanonicalModel, expression::Symbol, bus_count::Int64)

    time_steps = model_time_steps(canonical)
    devices_netinjection = _remove_undef!(canonical.expressions[expression])

    canonical.constraints[:CopperPlateBalance] = JuMPConstraintArray(undef, time_steps)

    for t in time_steps
        canonical.constraints[:CopperPlateBalance][t] = JuMP.@constraint(canonical.JuMPmodel, sum(canonical.expressions[expression].data[1:bus_count, t]) == 0)
    end

    return

end
