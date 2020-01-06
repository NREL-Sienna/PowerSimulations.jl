abstract type AbstractReservesFormulation <: AbstractServiceFormulation end
struct RangeReserve <: AbstractReservesFormulation end
############################### Reserve Variables` #########################################
"""
This function add the variables for reserves to the model
"""
function activeservice_variables!(psi_container::PSIContainer,
                                  services::IS.FlattenIteratorWrapper{SR},
                                  service_devices::Dict{NamedTuple{(:type, :name),Tuple{DataType,String}},PSY.ServiceContributingDevices}) where SR<:PSY.Reserve

    function get_ub_val(d::PSY.Device)
        return d.tech.activepowerlimits.max
    end
    function get_ub_val(d::PSY.RenewableGen)
        return d.tech.rating
    end
    for service in services
        devices = service_devices[(type = typeof(service), name = PSY.get_name(service))]
        add_variable(psi_container,
                    devices.contributing_devices,
                    Symbol("$(PSY.get_name(service))_$SR"),
                    false;
                    ub_value = d -> get_ub_val(d),
                    lb_value = d -> 0 )
    end
    return
end

################################## Reserve Requirement Constraint ##########################
# This function can be generalized later for any constraint of type Sum(req_var) >= requirement,
# it will only need to be specific to the names and get forecast string.
function service_requirement_constraints!(psi_container::PSIContainer,
                                services::IS.FlattenIteratorWrapper{SR},
                                model::ServiceModel{SR, RangeReserve}) where SR<:PSY.Reserve
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    initial_time = model_initial_time(psi_container)
    time_steps = model_time_steps(psi_container)
    device_total = length(services)

    constraint_name = Symbol("requirement_$SR")
    names = (PSY.get_name(s) for s in services)
    constraint = add_cons_container!(psi_container, constraint_name, names, time_steps)
    ts_data = Vector{DeviceTimeSeries}()

    for service in services
        name = PSY.get_name(service)
        active_power = PSY.get_requirement(service)
        if use_forecast_data
            forecast = PSY.get_forecast(PSY.Deterministic,
                                        service,
                                        initial_time,
                                        "get_requirement",
                                        length(time_steps))
            ts_vector = TS.values(PSY.get_data(forecast))
        else
            ts_vector = ones(time_steps[end])
        end
        push!(ts_data, DeviceTimeSeries(name, 0, active_power, ts_vector, nothing))
    end
    if parameters
        param = add_param_container!(psi_container, UpdateRef{SR}("get_requirement"), names, time_steps)

        for data in ts_data, t in time_steps
            param[data.name, t] = PJ.add_parameter(psi_container.JuMPmodel, 
                                                   data.timeseries[t])
            reserve_variable = get_variable(psi_container, Symbol("$(data.name)_$SR"))
            constraint[data.name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                        sum(reserve_variable[:,t]) >= param[data.name, t] * data.multiplier)
        end
    else
        for data in ts_data, t in time_steps
            reserve_variable = get_variable(psi_container, Symbol("$(data.name)_$SR"))
            constraint[data.name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                    sum(reserve_variable[:,t]) >= data.timeseries[t] * data.multiplier)
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
