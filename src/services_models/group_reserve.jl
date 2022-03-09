
############################### Reserve Variables` #########################################
"""
This function checks if the variables for reserves were created
"""
function check_activeservice_variables(
    container::OptimizationContainer,
    contributing_services::Vector{T},
) where {T <: PSY.Service}
    for service in contributing_services
        get_variable(
            container,
            ActivePowerReserveVariable(),
            typeof(service),
            PSY.get_name(service),
        )
    end
    return
end

################################## Reserve Requirement Constraint ##########################
"""
This function creates the requirement constraint that will be attained by the apropriate services
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{RequirementConstraint},
    service::SR,
    contributing_services::Vector{<:PSY.Service},
    model::ServiceModel{SR, GroupReserve},
) where {SR <: PSY.StaticReserveGroup}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    add_constraints_container!(
        container,
        RequirementConstraint(),
        SR,
        [service_name],
        time_steps;
        meta=service_name,
    )
    constraint = get_constraint(container, RequirementConstraint(), SR, service_name)
    use_slacks = get_use_slacks(model)
    reserve_variables = [
        get_variable(container, ActivePowerReserveVariable(), typeof(r), PSY.get_name(r)) for r in contributing_services
    ]

    requirement = PSY.get_requirement(service)
    for t in time_steps
        resource_expression = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}()
        for reserve_variable in reserve_variables
            JuMP.add_to_expression!(resource_expression, sum(reserve_variable[:, t]))
        end
        if use_slacks
            resource_expression += slack_vars[t]
        end
        constraint[service_name, t] =
            JuMP.@constraint(container.JuMPmodel, resource_expression >= requirement)
    end

    return
end
