function copper_plate(psi_container::PSIContainer, expression::Symbol, bus_count::Int)

    time_steps = model_time_steps(psi_container)
    devices_netinjection = _remove_undef!(psi_container.expressions[expression])

    constraint_val = JuMPConstraintArray(undef, time_steps)
    assign_constraint!(psi_container, "CopperPlateBalance", constraint_val)

    for t in time_steps
        constraint_val[t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum(psi_container.expressions[expression].data[1:bus_count, t]) == 0
        )
    end

    return

end
