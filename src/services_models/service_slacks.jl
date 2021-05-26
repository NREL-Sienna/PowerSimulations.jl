function reserve_slacks(
    optimization_container::OptimizationContainer,
    ::Type{T},
) where {T <: PSY.Reserve}
    variable =
        add_var_container!(optimization_container, ReserveRequirementSlack, T, time_steps)

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
