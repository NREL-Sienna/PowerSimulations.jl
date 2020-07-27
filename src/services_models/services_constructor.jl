function construct_services!(
    psi_container::PSIContainer,
    sys::PSY.System,
    services_template::Dict{Symbol, ServiceModel},
    devices_template::Dict{Symbol, DeviceModel},
)
    isempty(services_template) && return
    services_mapping = PSY.get_contributing_device_mapping(sys)
    for service_model in values(services_template)
        @debug "Building $(service_model.service_type) with $(service_model.formulation) formulation"
        services = PSY.get_components(service_model.service_type, sys)
        if validate_available_services(service_model.service_type, services)
            construct_service!(
                psi_container,
                services,
                services_mapping,
                service_model,
                devices_template,
            )
        end
    end
    return
end

function construct_service!(
    psi_container::PSIContainer,
    services::IS.FlattenIteratorWrapper{SR},
    services_mapping::PSY.ServiceContributingDevicesMapping,
    model::ServiceModel{SR, RangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
) where {SR <: PSY.Reserve}
    time_steps = model_time_steps(psi_container)
    names = (PSY.get_name(s) for s in services)

    incompatible_device_types = Vector{DataType}()
    for model in values(devices_template)
        formulation = get_formulation(model)
        if formulation == FixedOutput
            @info "$(formulation) for $(get_device_type(model)) is not compatible with the provision of reserve services"
            push!(incompatible_device_types, get_device_type(model))
        end
    end

    if model_has_parameters(psi_container)
        container = add_param_container!(
            psi_container,
            UpdateRef{SR}("service_requirement", "get_requirement"),
            names,
            time_steps,
        )
        get_parameter_array(container)
    end

    add_cons_container!(psi_container, constraint_name(REQUIREMENT, SR), names, time_steps)

    for service in services
        contributing_devices =
            services_mapping[(
                type = typeof(service),
                name = PSY.get_name(service),
            )].contributing_devices
        if !isempty(incompatible_device_types)
            contributing_devices =
                [d for d in contributing_devices if typeof(d) ∉ incompatible_device_types]
        end

        #Variables
        activeservice_variables!(psi_container, service, contributing_devices)
        # Constraints
        service_requirement_constraint!(psi_container, service, model)
        modify_device_model!(devices_template, model, contributing_devices)
    end
    return
end

function construct_service!(
    psi_container::PSIContainer,
    services::IS.FlattenIteratorWrapper{SR},
    services_mapping::PSY.ServiceContributingDevicesMapping,
    model::ServiceModel{SR, SupplementalRangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
) where {SR <: PSY.SupplementalStaticReserve}
    time_steps = model_time_steps(psi_container)
    names = (PSY.get_name(s) for s in services)

    incompatible_device_types = Vector{DataType}()
    for model in values(devices_template)
        formulation = get_formulation(model)
        if formulation == FixedOutput
            @info "$(formulation) for $(get_device_type(model)) is not compatible with the provision of reserve services"
            push!(incompatible_device_types, get_device_type(model))
        end
    end

    if model_has_parameters(psi_container)
        container = add_param_container!(
            psi_container,
            UpdateRef{SR}("service_requirement", "get_requirement"),
            names,
            time_steps,
        )
        get_parameter_array(container)
    end

    add_cons_container!(psi_container, constraint_name(REQUIREMENT, SR), names, time_steps)

    for service in services
        contributing_devices =
            services_mapping[(
                type = typeof(service),
                name = PSY.get_name(service),
            )].contributing_devices
        if !isempty(incompatible_device_types)
            contributing_devices =
                [d for d in contributing_devices if typeof(d) ∉ incompatible_device_types]
        end

        #Variables
        activeservice_variables!(psi_container, service, contributing_devices)
        offline_activeservice_variables!(psi_container, service, contributing_devices)
        # Constraints
        service_requirement_constraint!(psi_container, service, model)
        modify_device_model!(devices_template, model, contributing_devices)
    end
    return
end
