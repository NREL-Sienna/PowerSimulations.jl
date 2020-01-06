abstract type AbstractReservesFormulation <: AbstractServiceFormulation end
struct RangeReserve <: AbstractReservesFormulation end
############################### Reserve Variables` #########################################
"""
This function add the variables for reserves to the model
"""
function activeservice_variables!(psi_container::PSIContainer,
                                  service::SR,
                                  devices::Vector{<:PSY.Device}) where SR<:PSY.Reserve

    function get_ub_val(d::PSY.Device)
        return d.tech.activepowerlimits.max
    end
    function get_ub_val(d::PSY.RenewableGen)
        return d.tech.rating
    end
    
    add_variable(psi_container,
                 devices,
                 Symbol("$(PSY.get_name(service))_$SR"),
                 false;
                 ub_value = d -> get_ub_val(d),
                 lb_value = d -> 0 )
    return
end

################################## Reserve Requirement Constraint ##########################
# This function can be generalized later for any constraint of type Sum(req_var) >= requirement,
# it will only need to be specific to the names and get forecast string.
function service_requirement_constraint!(psi_container::PSIContainer,
                                         service::SR) where {SR<:PSY.Reserve}
    time_steps = model_time_steps(psi_container)
    parameters = model_has_parameters(psi_container)
    forecast = model_uses_forecasts(psi_container)
    initial_time = model_initial_time(psi_container)
    service_name = PSY.get_name(service)
    reserve_variable = get_variable(psi_container, Symbol("$(service_name)_$SR"))
    constraint_name = Symbol(service_name, "_requirement_$SR")
    constraint = add_cons_container!(psi_container, constraint_name, time_steps)
    requirement = PSY.get_requirement(service)
    if forecast
        ts_vector = TS.values(PSY.get_data(PSY.get_forecast(PSY.Deterministic,
                                                            service,
                                                            initial_time,
                                                            "get_requirement")))
    else
        ts_vector = ones(time_steps[end])
    end
    if parameters
        param = include_parameters(psi_container, ts_vector,
                                   UpdateRef{SR}("get_requirement", service_name), time_steps)
        for t in time_steps
            constraint[t] = JuMP.@constraint(psi_container.JuMPmodel,
                                         sum(reserve_variable[:,t]) >= param[t]*requirement)
        end
    else
        for t in time_steps
            constraint[t] = JuMP.@constraint(psi_container.JuMPmodel,
                                    sum(reserve_variable[:,t]) >= ts_vector[t]*requirement)
        end
    end
    return
end

function modify_device_model!(devices_template::Dict{Symbol, DeviceModel},
                              service_model::ServiceModel{<:PSY.Reserve, RangeReserve},
                              contributing_devices::Vector{<:PSY.Device})
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

function include_service!(constraint_data::DeviceRange,
                          services::Vector{SR},
                          ::ServiceModel{SR, <:AbstractReservesFormulation}) where SR <: PSY.Reserve{PSY.ReserveUp}
        services_ub = Vector{Symbol}(undef, length(services))
        for (ix, service) in enumerate(services)
            push!(constraint_data.additional_terms_ub, Symbol("$(PSY.get_name(service))_$SR"))
        end
    return
end

function include_service!(constraint_data::DeviceRange,
                          services::Vector{SR},
                          ::ServiceModel{SR, <:AbstractReservesFormulation}) where SR <: PSY.Reserve{PSY.ReserveDown}
        services_ub = Vector{Symbol}(undef, length(services))
        for (ix, service) in enumerate(services)
            #uses the upper bound of the (downward) service requirement to determine a constraint LB
            push!(constraint_data.additional_terms_lb, Symbol("$(PSY.get_name(service))_$SR"))
        end
    return
end

function _device_services!(constraint_data::DeviceRange,
                          device::D,
                          model::DeviceModel) where D <: PSY.Device
    for service_model in get_services(model)
        if PSY.has_service(device, service_model.service_type)
            services = [s for s in PSY.get_services(device) if isa(s, service_model.service_type)]
            @assert !isempty(services)
            include_service!(constraint_data, services, service_model)
        end
    end
    return
end
