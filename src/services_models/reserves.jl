abstract type AbstractReservesFormulation <: AbstractServiceFormulation end
struct RangeReserve <: AbstractReservesFormulation end
struct OperatingReserveDemandCurve <: AbstractReservesFormulation end
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

function activerequirement_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ORDC},
)
    add_variable(
        psi_container,
        devices,
        variable_name(SERVICE_REQUIREMENT, PSY.ORDC),
        false;
        lb_value = x -> 0.0,
    )
    return
end

################################## Reserve Requirement Constraint ##########################
# This function can be generalized later for any constraint of type Sum(req_var) >= requirement,
# it will only need to be specific to the names and get forecast string.
function service_requirement_constraint!(
    psi_container::PSIContainer,
    service::SR,
    model::ServiceModel{SR, RangeReserve},
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
                sum(reserve_variable[:, t]) >= param[name, t]
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

function service_requirement_constraint!(
    psi_container::PSIContainer,
    service::SR,
    model::ServiceModel{SR, OperatingReserveDemandCurve},
) where {SR <: PSY.Reserve}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    time_steps = model_time_steps(psi_container)
    name = PSY.get_name(service)
    constraint = get_constraint(psi_container, constraint_name(REQUIREMENT, SR))
    reserve_variable = get_variable(psi_container, variable_name(name, SR))
    requirement_variable =
        get_variable(psi_container, variable_name(SERVICE_REQUIREMENT, SR))

    for t in time_steps
        constraint[name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum(reserve_variable[:, t]) >= requirement_variable[name, t]
        )
    end

    return
end

function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{SR},
    ::Type{OperatingReserveDemandCurve},
) where {SR <: PSY.Reserve}
    add_to_cost(
        psi_container,
        devices,
        variable_name(SERVICE_REQUIREMENT, SR),
        :variable,
        -1.0,
    )
    return
end

function modify_device_model!(
    devices_template::Dict{Symbol, DeviceModel},
    service_model::ServiceModel{<:PSY.Reserve, <:AbstractReservesFormulation},
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

function include_service!(constraint_data::DeviceTimeSeries, services, SM::ServiceModel)
    range_data = constraint_data.range
    isnothing(range_data) && return
    include_service!(range_data, services, SM)
    return
end

function include_service!(
    constraint_data::DeviceRange,
    services,
    ::ServiceModel{SR, <:AbstractReservesFormulation},
) where {SR <: PSY.Reserve{PSY.ReserveUp}}
    for (ix, service) in enumerate(services)
        push!(
            constraint_data.additional_terms_ub,
            constraint_name(PSY.get_name(service), SR),
        )
    end
    return
end

function include_service!(
    constraint_data::DeviceRange,
    services,
    ::ServiceModel{SR, <:AbstractReservesFormulation},
) where {SR <: PSY.Reserve{PSY.ReserveDown}}
    for (ix, service) in enumerate(services)
        push!(
            constraint_data.additional_terms_lb,
            constraint_name(PSY.get_name(service), SR),
        )
    end
    return
end

function add_device_services!(
    constraint_data::RangeConstraintsData,
    device::D,
    model::DeviceModel,
) where {D <: PSY.Device}
    for service_model in get_services(model)
        if PSY.has_service(device, service_model.service_type)
            services =
                (s for s in PSY.get_services(device) if isa(s, service_model.service_type))
            @assert !isempty(services)
            include_service!(constraint_data, services, service_model)
        end
    end
    return
end

function add_device_services!(
    constraint_data_in::RangeConstraintsData,
    constraint_data_out::RangeConstraintsData,
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
