function reserve_slacks(
    optimization_container::OptimizationContainer,
    service::T,
) where {T <: PSY.Reserve}
    time_steps = model_time_steps(optimization_container)
    variable = add_var_container!(
        optimization_container,
        ReserveRequirementSlack(),
        T,
        PSY.get_name(service),
        time_steps,
    )

    for jx in time_steps
        variable[jx] = JuMP.@variable(
            optimization_container.JuMPmodel,
            # base_name ="$slacks_{$(jx)}",
            lower_bound = 0.0
        )
        JuMP.add_to_expression!(
            optimization_container.cost_function,
            variable[jx] * SERVICES_SLACK_COST,
        )
    end
    return variable
end
