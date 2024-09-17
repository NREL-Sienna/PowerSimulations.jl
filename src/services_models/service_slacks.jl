function reserve_slacks!(
    container::OptimizationContainer,
    service::T,
) where {T <: Union{PSY.Reserve, PSY.ReserveNonSpinning}}
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
            get_jump_model(container),
            base_name = "slack_{$(PSY.get_name(service)), $(t)}",
            lower_bound = 0.0
        )
        add_to_objective_invariant_expression!(container, variable[t] * SERVICES_SLACK_COST)
    end
    return variable
end

function transmission_interface_slacks!(
    container::OptimizationContainer,
    service::T,
) where {T <: PSY.TransmissionInterface}
    time_steps = get_time_steps(container)

    for variable_type in [InterfaceFlowSlackUp, InterfaceFlowSlackDown]
        variable = add_variable_container!(
            container,
            variable_type(),
            T,
            PSY.get_name(service),
            time_steps,
        )
        penalty = PSY.get_violation_penalty(service)
        name = PSY.get_name(service)
        for t in time_steps
            variable[t] = JuMP.@variable(
                get_jump_model(container),
                base_name = "$(T)_$(variable_type)_{$(name), $(t)}",
            )
            JuMP.set_lower_bound(variable[t], 0.0)

            add_to_objective_invariant_expression!(
                container,
                variable[t] * penalty,
            )
        end
    end

    return
end
