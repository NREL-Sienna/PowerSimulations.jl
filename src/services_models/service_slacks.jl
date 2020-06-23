function reserve_slacks(psi_container::PSIContainer, reserve_name::String)
    time_steps = model_time_steps(psi_container)
    var_name = variable_name(reserve_name, SLACK_UP)
    variable = add_var_container!(psi_container, var_name, time_steps)

    for jx in time_steps
        variable[jx] = JuMP.@variable(
            psi_container.JuMPmodel,
            base_name = "$(var_name)_{$(jx)}",
            lower_bound = 0.0
        )
        JuMP.add_to_expression!(psi_container.cost_function, variable[jx] * SERVICES_SLACK_COST)
    end
    return variable
end
