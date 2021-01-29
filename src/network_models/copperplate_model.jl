function copper_plate(
    optimization_container::OptimizationContainer,
    expression::Symbol,
    bus_count::Int,
)
    time_steps = model_time_steps(optimization_container)
    remove_undef!(optimization_container.expressions[expression])

    constraint_val = JuMPConstraintArray(undef, time_steps)
    assign_constraint!(optimization_container, "CopperPlateBalance", constraint_val)

    for t in time_steps
        constraint_val[t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            sum(optimization_container.expressions[expression].data[1:bus_count, t]) == 0
        )
    end

    return
end
