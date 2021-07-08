function copper_plate(container::OptimizationContainer, expression::Symbol, bus_count::Int)
    time_steps = get_time_steps(container)
    expressions = get_expression(container, expression)
    remove_undef!(container.expressions[expression])
    constraint = add_cons_container!(
        container,
        CopperPlateBalanceConstraint(),
        PSY.System,
        time_steps,
    )
    for t in time_steps
        constraint[t] = JuMP.@constraint(
            container.JuMPmodel,
            sum(expressions.data[i, t] for i in 1:bus_count) == 0
        )
    end

    return
end
