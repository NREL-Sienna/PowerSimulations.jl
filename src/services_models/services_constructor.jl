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
        construct_service!(psi_container,
                            sys,
                            service_devices,
                            service_model,
                            devices_template; kwargs...)
    end
    return
end

function construct_service!(psi_container::PSIContainer, 
                      sys::PSY.System,
                      service_devices::Dict{NamedTuple{(:type, :name),Tuple{DataType,String}},PSY.ServiceContributingDevices},
                      model::ServiceModel{SR, RangeReserve},
                      devices_template::Dict{Symbol, DeviceModel};
                      kwargs...) where SR<:PSY.Reserve
    services = PSY.get_components(model.service_type, sys)
    #Variables
    activeservice_variables!(psi_container, services, service_devices)
    # Constraints
    service_requirement_constraints!(psi_container, services, model)

    for contributing_devices in values(service_devices)
        modify_device_model!(devices_template,
                            model,
                            contributing_devices.contributing_devices)
    end

    return
end
