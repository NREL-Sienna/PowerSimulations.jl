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
        var = get(psi_container.variables, make_variable_name(ActiveServiceVariable, typeof(service)), nothing)
        if isnothing(var)
            @error "contributing service $name is not stored" sort!(get_variable_names(psi_container))
            throw(IS.InvalidValue("variable $name is not stored"))
        end
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

    if use_forecast_data && PSY.has_forecasts(service)
        ts_vector = TS.values(PSY.get_data(PSY.get_forecast(
            PSY.Deterministic,
            service,
            initial_time,
            "get_requirement",
            length(time_steps),
        )))
    else
        ts_vector = ones(time_steps[end])
    end

    requirement = PSY.get_requirement(service)
    if parameters
        param = get_parameter_array(
            psi_container,
            UpdateRef{SR}(SERVICE_REQUIREMENT, "get_requirement"),
        )
        for t in time_steps
            param[name, t] = PJ.add_parameter(psi_container.JuMPmodel, ts_vector[t])
            resource_expression = GenericAffExpr{Float64,VariableRef}()
            for reserve_variable in reserve_variables
                add_to_expression!(resource_expression, sum(reserve_variable[:, t]))
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
            resource_expression = GenericAffExpr{Float64,VariableRef}()
            for reserve_variable in reserve_variables
                add_to_expression!(resource_expression, sum(reserve_variable[:, t]))
            end
            constraint[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,resource_expression >= ts_vector[t] * requirement
            )
        end
    end
    return
end
