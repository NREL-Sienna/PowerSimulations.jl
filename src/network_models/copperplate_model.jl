function copper_plate!(::Type{CopperPlatePowerModel}, optimization_container::OptimizationContainer)
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

function copper_plate!(::Type{StandardPTDFModel}, optimization_container::OptimizationContainer)
    time_steps = model_time_steps(optimization_container)
    constraint_val = JuMPConstraintArray(undef, time_steps)
    assign_constraint!(optimization_container, "CopperPlateBalance", constraint_val)
    expressions = get_expression(optimization_container, :nodal_balance_active)
    remove_undef!(expressions)
    jump_model = get_jump_model(optimization_container)
    bus_count = 1:length(axes(expressions)[1])
    for bus in axes(expressions)[1], t in time_steps
        constraint_val[t] = JuMP.@constraint(jump_model, sum(expressions.data[i, t] for i in bus_count) == 0)
    end

    return
end
