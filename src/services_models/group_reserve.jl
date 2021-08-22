struct GroupReserve <: AbstractReservesFormulation end
############################### Reserve Variables` #########################################
"""
This function checks if the variables for reserves were created
"""
function check_activeservice_variables(
    optimization_container::OptimizationContainer,
    contributing_services::Vector{T},
) where {T <: PSY.Service}
    for service in contributing_services
        get_variable(
            optimization_container,
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
function service_requirement_constraint!(
    optimization_container::OptimizationContainer,
    service::SR,
    ::ServiceModel{SR, GroupReserve},
    contributing_services::Vector{<:PSY.Service},
) where {SR <: PSY.StaticReserveGroup}
    initial_time = model_initial_time(optimization_container)
    @debug initial_time
    time_steps = model_time_steps(optimization_container)
    name = PSY.get_name(service)
    constraint = get_constraint(optimization_container, RequirementConstraint(), SR)
    use_slacks = get_services_slack_variables(optimization_container.settings)
    reserve_variables = [
        get_variable(
            optimization_container,
            ActivePowerReserveVariable(),
            typeof(r),
            PSY.get_name(r),
        ) for r in contributing_services
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
        constraint[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            resource_expression >= requirement
        )
    end

    return
end
