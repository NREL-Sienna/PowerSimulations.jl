function reserve_slacks(
    container::OptimizationContainer,
    service::T,
) where {T <: PSY.Reserve}
    time_steps = get_time_steps(container)
    variable = add_var_container!(
        container,
        ReserveRequirementSlack(),
        T,
        PSY.get_name(service),
        time_steps,
    )

    for jx in time_steps
        variable[jx] = JuMP.@variable(
            container.JuMPmodel,
            base_name = "slacks_{$(jx)}",
            lower_bound = 0.0
        )
        JuMP.add_to_expression!(container.cost_function, variable[jx] * SERVICES_SLACK_COST)
    end
    return variable
end
