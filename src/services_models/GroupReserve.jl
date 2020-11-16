struct GroupReserve <: AbstractReservesFormulation end
############################### Reserve Variables` #########################################
"""
This function checks if the variables for reserves were created
"""
function check_activeservice_variables(
    psi_container::PSIContainer,
    contributing_services::Vector{<:PSY.Service},
)
    for service in contributing_services
        get_variable(psi_container, PSY.get_name(service), typeof(service))
    end
    return
end

################################## Reserve Requirement Constraint ##########################
"""
This function creates the requirement constraint that will be attained by the apropriate services
"""
function service_requirement_constraint!(
    psi_container::PSIContainer,
    service::SR,
    ::ServiceModel{SR, GroupReserve},
    contributing_services::Vector{<:PSY.Service},
) where {SR <: PSY.StaticReserveGroup}
    parameters = model_has_parameters(psi_container)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    time_steps = model_time_steps(psi_container)
    name = PSY.get_name(service)
    constraint = get_constraint(psi_container, make_constraint_name(REQUIREMENT, SR))
    use_slacks = get_services_slack_variables(psi_container.settings)
    reserve_variables = [
        get_variable(psi_container, PSY.get_name(r), typeof(r))
        for r in contributing_services
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
        constraint[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, resource_expression >= requirement)
    end

    return
end
