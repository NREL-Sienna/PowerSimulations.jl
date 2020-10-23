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
    use_forecast_data = model_uses_forecasts(psi_container)
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

    ts_vectors = [get_time_series(psi_container, s, "requirement") for s in contributing_services]
    ts_vector = sum(hcat(ts_vectors...), dims = 2)

    requirement = PSY.get_requirement(service)
    if parameters
        param = get_parameter_array(
            psi_container,
            UpdateRef{SR}(SERVICE_REQUIREMENT, "requirement"),
        )
        for t in time_steps
            param[name, t] = PJ.add_parameter(psi_container.JuMPmodel, ts_vector[t])
            resource_expression = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}()
            for reserve_variable in reserve_variables
                JuMP.add_to_expression!(resource_expression, sum(reserve_variable[:, t]))
            end
            if use_slacks
                resource_expression += slack_vars[t]
            end
            constraint[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                resource_expression >= param[name, t] * requirement
            )
        end
    else
        for t in time_steps
            resource_expression = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}()
            for reserve_variable in reserve_variables
                JuMP.add_to_expression!(resource_expression, sum(reserve_variable[:, t]))
            end
            constraint[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                resource_expression >= ts_vector[t] * requirement
            )
        end
    end
    return
end
