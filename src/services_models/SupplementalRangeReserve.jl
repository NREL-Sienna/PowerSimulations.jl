struct SupplementalRangeReserve <: AbstractReservesFormulation end
############################### Reserve Variables` #########################################
"""Adds the offline active service variables related to the SupplementalStaticReserve."""
function offline_activeservice_variables!(
    psi_container::PSIContainer,
    service::SR,
    contributing_devices::Vector{<:PSY.Device},
) where {SR <: PSY.SupplementalStaticReserve}
    add_variable(
        psi_container,
        contributing_devices,
        variable_name(PSY.get_name(service)*"_off", SR),
        false;
        lb_value = d -> 0,
    )
    return
end

################################## Reserve Requirement Constraint ##########################
"""Creates the service requirement of SupplementalStaticReserve (Which can be attained by online and offline devices)."""
function service_requirement_constraint!(
    psi_container::PSIContainer,
    service::SR,
    model::ServiceModel{SR, SupplementalRangeReserve},
) where {SR <: PSY.SupplementalStaticReserve}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    time_steps = model_time_steps(psi_container)
    name = PSY.get_name(service)
    constraint = get_constraint(psi_container, constraint_name(REQUIREMENT, SR))
    reserve_variable = get_variable(psi_container, variable_name(name, SR))
    reserve_variable_off = get_variable(psi_container, variable_name(name*"_off", SR))

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
                sum(reserve_variable[:, t])+sum(reserve_variable_off[:, t]) >= param[name, t]
            )
        end
    else
        for t in time_steps
            constraint[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                sum(reserve_variable[:, t])+sum(reserve_variable_off[:, t]) >= ts_vector[t] * requirement
            )
        end
    end
    return
end

"""adds services to device model"""
function modify_device_model!(
    devices_template::Dict{Symbol, DeviceModel},
    service_model::ServiceModel{<:PSY.SupplementalStaticReserve, SupplementalRangeReserve},
    contributing_devices::Vector{<:PSY.Device},
)
    device_types = unique(typeof.(contributing_devices))
    for dt in device_types
        for (device_model_name, device_model) in devices_template
            # add message here when it exists
            device_model.device_type != dt && continue
            service_model in device_model.services && continue
            push!(device_model.services, service_model)
        end
    end

    return
end
