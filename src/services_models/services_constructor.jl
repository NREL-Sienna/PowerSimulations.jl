function _filter_service_mapping(::Type{SR}, map) where SR<:PSY.Service
    return filter(p->(p.first.type <: SR), map)
end

function construct_services!(psi_container::PSIContainer,
                             sys::PSY.System,
                             services_template::Dict{Symbol, ServiceModel},
                             devices_template::Dict{Symbol, DeviceModel};
                             kwargs...)
    isempty(services_template) && return
    services_mapping = PSY.get_contributing_device_mapping(sys)
    for service_model in values(services_template)
        service_devices = _filter_service_mapping(service_model.service_type, services_mapping)
        services = PSY.get_components(service_model.service_type, sys)
        construct_service!(psi_container,
                            services,
                            service_devices,
                            service_model,
                            devices_template; kwargs...)
    end
    return
end

function construct_service!(psi_container::PSIContainer, 
                      services::IS.FlattenIteratorWrapper{SR},
                      service_devices::Dict{NamedTuple{(:type, :name),Tuple{DataType,String}},PSY.ServiceContributingDevices},
                      model::ServiceModel{SR, RangeReserve},
                      devices_template::Dict{Symbol, DeviceModel};
                      kwargs...) where SR<:PSY.Reserve

    time_steps = model_time_steps(psi_container)
    names = (PSY.get_name(s) for s in services)
    add_param_container!(psi_container, UpdateRef{SR}("get_requirement"), names, time_steps)
    constraint_name = Symbol("requirement_$SR")
    add_cons_container!(psi_container, constraint_name, names, time_steps)

    for service in services
        contributing_devices = service_devices[(type = typeof(service), 
                                                name = PSY.get_name(service))].contributing_devices
        #Variables
        activeservice_variables!(psi_container, service, contributing_devices)
        # Constraints
        service_requirement_constraint!(psi_container, service, model)
        modify_device_model!(devices_template, model, contributing_devices)
    end
    return
end
