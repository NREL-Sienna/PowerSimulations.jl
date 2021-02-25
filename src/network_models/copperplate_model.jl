function copper_plate!(optimization_container::OptimizationContainer)
    time_steps = model_time_steps(optimization_container)
    constraint_val = JuMPConstraintArray(undef, time_steps)
    assign_constraint!(optimization_container, "CopperPlateBalance", constraint_val)
    expressions = get_expression(optimization_container, :system_balance_active)
    remove_undef!(expressions)
    jump_model = get_jump_model(optimization_container)

    for t in time_steps
        constraint_val[t] = JuMP.@constraint(jump_model, expressions[t] == 0)
    end

    return
end
