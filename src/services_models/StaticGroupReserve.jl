############################### Reserve Variables` #########################################
"""
This function checks if the variables for reserves were created
"""
function check_activeservice_variables(
    psi_container::PSIContainer,
    contributing_services::Vector{<:PSY.Service},
)
    for service in contributing_services
        reserve_variable = get_variable(psi_container, variable_name(PSY.get_name(service), typeof(service)))
    end
    return
end

################################## Reserve Requirement Constraint ##########################
# This function can be generalized later for any constraint of type Sum(req_var) >= requirement,
# it will only need to be specific to the names and get forecast string.
function service_requirement_constraint!(
    psi_container::PSIContainer,
    service::SR,
    model::ServiceModel{SR, RangeReserve},
    contributing_services::Vector{<:PSY.Service},
) where {SR <: PSY.StaticGroupReserve}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    time_steps = model_time_steps(psi_container)
    name = PSY.get_name(service)
    constraint = get_constraint(psi_container, constraint_name(REQUIREMENT, SR))
    reserve_variables = [get_variable(psi_container, variable_name(PSY.get_name(r), typeof(r))) for r in contributing_services]

    if use_forecast_data
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
            param[name, t] =
                PJ.add_parameter(psi_container.JuMPmodel, ts_vector[t] * requirement)
            constraint[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                sum(sum(reserve_variable[:, t]) for reserve_variable in reserve_variables) >= param[name, t]
            )
        end
    else
        for t in time_steps
            constraint[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                sum(sum(reserve_variable[:, t]) for reserve_variable in reserve_variables) >= ts_vector[t] * requirement
            )
        end
    end
    return
end

# function modify_device_model!(
#     devices_template::Dict{Symbol, DeviceModel},
#     service_model::ServiceModel{<:PSY.Reserve, RangeReserve},
#     contributing_devices::Vector{<:PSY.Device},
# )
#     device_types = unique(typeof.(contributing_devices))
#     for dt in device_types
#         for (device_model_name, device_model) in devices_template
#             # add message here when it exists
#             device_model.device_type != dt && continue
#             service_model in device_model.services && continue
#             push!(device_model.services, service_model)
#         end
#     end

#     return
# end

function include_service!(
    constraint_data::DeviceRange,
    services,
    ::ServiceModel{SR, <:AbstractReservesFormulation},
) where {SR <: PSY.StaticGroupReserve}
    return
end
