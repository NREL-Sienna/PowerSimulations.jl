function copper_plate(canonical::CanonicalModel, expression::Symbol, bus_count::Int64)

    time_steps = model_time_steps(canonical_model)
    devices_netinjection = _remove_undef!(canonical_model.expressions[expression])

    canonical_model.constraints[:CopperPlateBalance] = JuMPConstraintArray(undef, time_steps)

    for t in time_steps
        canonical_model.constraints[:CopperPlateBalance][t] = JuMP.@constraint(canonical_model.JuMPmodel, sum(canonical_model.expressions[expression].data[1:bus_count, t]) == 0)
    end

    return

end
