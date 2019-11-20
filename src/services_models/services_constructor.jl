function construct_services!(canonical::Canonical,
                             sys::PSY.System,
                             services_template::Dict{Symbol,ServiceModel};
                             kwargs...)
    isempty(services_template) && return
    expression_list = Vector{Symbol}()
    for service_model in values(services_template)
        services = PSY.get_components(service_model.service_type, sys)
        for service in services
            add_service!(canonical, service, service_model, expression_list; kwargs...)
        end
    end
    # post constraints in expression dict
    return
end

function add_service!(canonical::Canonical, service::SR,
                      model::ServiceModel{SR, RangeUpwardReserve},
                      expression_list::Vector{Symbol};
                      kwargs...) where {SR<:PSY.Reserve}
        devices = PSY.get_contributingdevices(service)
        #Variables
        activeservice_variables!(canonical, service, devices)
        #requirement constraint Constraints
        service_requirement_constraint!(canonical, service)
        # add to
        add_to_service_expression!(canonical, model, service, expression_list)
    return
end
