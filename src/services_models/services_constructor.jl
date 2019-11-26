function _filter_service_mapping(::Type{SR}, map) where SR<:PSY.Reserve
    return filter(p->isequal(p.first.type, SR), map)
end

function construct_services!(psi_container::PSIContainer,
                             sys::PSY.System,
                             services_template::Dict{Symbol,ServiceModel};
                             kwargs...)
    isempty(services_template) && return
    services_mapping = PSY.get_contributing_device_mapping(sys)
    for service_model in values(services_template)
        contributing_devices = _filter_service_mapping(service_model.service_type, services_mapping)
        for value in values(contributing_devices)
            add_service!(psi_container, value.service, service_model, value.contributing_devices; kwargs...)
        end
    end
    # post constraints in expression dict
    return
end

function add_service!(psi_container::PSIContainer, service::SR,
                      model::ServiceModel{SR, RangeUpwardReserve},
                      contributing_devices::Vector{PSY.Device};
                      kwargs...) where SR<:PSY.Reserve
        #Variables
        activeservice_variables!(psi_container, service, contributing_devices)
        #requirement constraint Constraints
        service_requirement_constraint!(psi_container, service)
        # add to
        #add_to_service_expression!(psi_container, model, service, expression_list)
    return
end
