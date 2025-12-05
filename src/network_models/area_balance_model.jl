function add_constraints!(
    container::OptimizationContainer,
    ::Type{CopperPlateBalanceConstraint},
    sys::PSY.System,
    model::NetworkModel{AreaBalancePowerModel},
)
    expressions = get_expression(container, ActivePowerBalance(), PSY.Area)
    area_names, time_steps = axes(expressions)

    constraints = add_constraints_container!(
        container,
        CopperPlateBalanceConstraint(),
        PSY.Area,
        area_names,
        time_steps,
    )

    for a in area_names, t in time_steps
        constraints[a, t] =
            JuMP.@constraint(get_jump_model(container), expressions[a, t] == 0.0)
    end
    return
end
