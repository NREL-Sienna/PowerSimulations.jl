function reserve_slacks(optimization_container::OptimizationContainer, reserve_name::String)
    time_steps = model_time_steps(optimization_container)
    var_name = make_variable_name(reserve_name, SLACK_UP)
    variable = add_var_container!(optimization_container, var_name, time_steps)

    for jx in time_steps
        variable[jx] = JuMP.@variable(
            optimization_container.JuMPmodel,
            base_name = "$(var_name)_{$(jx)}",
            lower_bound = 0.0
        )
        JuMP.add_to_expression!(
            optimization_container.cost_function,
            variable[jx] * SERVICES_SLACK_COST,
        )
    end
    return variable
end
