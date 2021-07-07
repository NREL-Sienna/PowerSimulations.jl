function copper_plate(
    optimization_container::OptimizationContainer,
    expression::Symbol,
    bus_count::Int,
)
    time_steps = get_time_steps(optimization_container)
    expressions = get_expression(optimization_container, expression)
    remove_undef!(optimization_container.expressions[expression])
    constraint = add_cons_container!(
        optimization_container,
        CopperPlateBalanceConstraint(),
        PSY.System,
        time_steps,
    )
    for t in time_steps
        constraint[t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            sum(expressions.data[i, t] for i in 1:bus_count) == 0
        )
    end

    return
end
