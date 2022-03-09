function reserve_slacks(
    container::OptimizationContainer,
    service::T,
) where {T <: PSY.Reserve}
    time_steps = get_time_steps(container)
    variable = add_variable_container!(
        container,
        ReserveRequirementSlack(),
        T,
        PSY.get_name(service),
        time_steps,
    )

    for t in time_steps
        variable[t] = JuMP.@variable(
            container.JuMPmodel,
            base_name = "slack_{$(PSY.get_name(service)), $(t)}",
            lower_bound = 0.0
        )
        add_to_objective_invariant_expression!(container, variable[t] * SERVICES_SLACK_COST)
    end
    return variable
end
