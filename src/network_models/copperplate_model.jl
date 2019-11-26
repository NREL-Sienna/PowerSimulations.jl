function copper_plate(psi_container::PSIContainer, expression::Symbol, bus_count::Int64)

    time_steps = model_time_steps(psi_container)
    devices_netinjection = _remove_undef!(psi_container.expressions[expression])

    psi_container.constraints[:CopperPlateBalance] = JuMPConstraintArray(undef, time_steps)

    for t in time_steps
        psi_container.constraints[:CopperPlateBalance][t] = JuMP.@constraint(psi_container.JuMPmodel, sum(psi_container.expressions[expression].data[1:bus_count, t]) == 0)
    end

    return

end
