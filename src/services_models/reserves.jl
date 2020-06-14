abstract type AbstractReservesFormulation <: AbstractServiceFormulation end
struct RangeReserve <: AbstractReservesFormulation end
############################### Reserve Variables` #########################################
"""
This function add the variables for reserves to the model
"""
function activeservice_variables!(
    psi_container::PSIContainer,
    service::SR,
    contributing_devices::Vector{<:PSY.Device},
) where {SR <: PSY.Reserve}
    add_variable(
        psi_container,
        contributing_devices,
        variable_name(PSY.get_name(service), SR),
        false;
        lb_value = d -> 0,
    )
    return
end

################################## Reserve Requirement Constraint ##########################
# This function can be generalized later for any constraint of type Sum(req_var) >= requirement,
# it will only need to be specific to the names and get forecast string.
function service_requirement_constraint!(
    psi_container::PSIContainer,
    service::SR,
    ::ServiceModel{SR, RangeReserve},
) where {SR <: PSY.Reserve}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    time_steps = model_time_steps(psi_container)
    name = PSY.get_name(service)
    constraint = get_constraint(psi_container, constraint_name(REQUIREMENT, SR))
    reserve_variable = get_variable(psi_container, variable_name(name, SR))

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

    var_name_up = variable_name(name, SLACK_UP)
    variable_up = add_var_container!(psi_container, var_name_up, [name], time_steps)

    for ix in [name], jx in time_steps
        variable_up[ix, jx] = JuMP.@variable(
            psi_container.JuMPmodel,
            base_name = "$(var_name_up)_{$(ix), $(jx)}",
            lower_bound = 0.0
        )
        JuMP.add_to_expression!(
            psi_container.cost_function,
            variable_up[ix, jx] * SLACK_COST,
        )
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
                sum(reserve_variable[:, t]) + variable_up[name, t] >= param[name, t]
            )
        end
    else
        for t in time_steps
            constraint[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                sum(reserve_variable[:, t]) >= ts_vector[t] * requirement
            )
        end
    end
    return
end

function modify_device_model!(
    devices_template::Dict{Symbol, DeviceModel},
    service_model::ServiceModel{<:PSY.Reserve, RangeReserve},
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

function include_service!(
    constraint_info::DeviceRangeConstraintInfo,
    services,
    ::ServiceModel{SR, <:AbstractReservesFormulation},
) where {SR <: PSY.Reserve{PSY.ReserveUp}}
    for (ix, service) in enumerate(services)
        push!(
            constraint_info.additional_terms_ub,
            constraint_name(PSY.get_name(service), SR),
        )
    end
    return
end

function include_service!(
    constraint_info::DeviceRangeConstraintInfo,
    services,
    ::ServiceModel{SR, <:AbstractReservesFormulation},
) where {SR <: PSY.Reserve{PSY.ReserveDown}}
    for (ix, service) in enumerate(services)
        push!(
            constraint_info.additional_terms_lb,
            constraint_name(PSY.get_name(service), SR),
        )
    end
    return
end

function add_device_services!(
    constraint_info::AbstractRangeConstraintInfo,
    device::D,
    model::DeviceModel,
) where {D <: PSY.Device}
    for service_model in get_services(model)
        if PSY.has_service(device, service_model.service_type)
            services =
                (s for s in PSY.get_services(device) if isa(s, service_model.service_type))
            @assert !isempty(services)
            include_service!(constraint_info, services, service_model)
        end
    end
    return
end

function add_device_services!(
    constraint_data_in::AbstractRangeConstraintInfo,
    constraint_data_out::AbstractRangeConstraintInfo,
    device::D,
    model::DeviceModel{D, <:AbstractStorageFormulation},
) where {D <: PSY.Storage}
    for service_model in get_services(model)
        if PSY.has_service(device, service_model.service_type)
            services =
                (s for s in PSY.get_services(device) if isa(s, service_model.service_type))
            @assert !isempty(services)
            if service_model.service_type <: PSY.Reserve{PSY.ReserveDown}
                for service in services
                    push!(
                        constraint_data_in.additional_terms_ub,
                        constraint_name(PSY.get_name(service), service_model.service_type),
                    )
                end
            elseif service_model.service_type <: PSY.Reserve{PSY.ReserveUp}
                for service in services
                    push!(
                        constraint_data_out.additional_terms_ub,
                        constraint_name(PSY.get_name(service), service_model.service_type),
                    )
                end
            end
        end
    end
    return
end
