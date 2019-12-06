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
        contributing_devices = _filter_service_mapping(service_model.service_type, services_mapping)
        for value in values(contributing_devices)
            add_service!(psi_container,
                         value.service,
                         service_model,
                         value.contributing_devices,
                         devices_template; kwargs...)
        end
    end
    return
end

function add_service!(psi_container::PSIContainer, service::SR,
                      model::ServiceModel{SR, RangeReserve},
                      contributing_devices::Vector{<:PSY.Device},
                      devices_template::Dict{Symbol, DeviceModel};
                      kwargs...) where SR<:PSY.Reserve
    #Variables
    activeservice_variables!(psi_container, service, contributing_devices)
    # Constraints
    service_requirement_constraint!(psi_container, service)

    modify_device_model!(devices_template,
                         model,
                         contributing_devices)

    return
end
