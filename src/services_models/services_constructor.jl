function get_incompatible_devices(devices_template::Dict)
    incompatible_device_types = Vector{DataType}()
    for model in values(devices_template)
        formulation = get_formulation(model)
        if formulation == FixedOutput
            if !isempty(get_services(model))
                @info "$(formulation) for $(get_component_type(model)) is not compatible with the provision of reserve services"
            end
            push!(incompatible_device_types, get_component_type(model))
        end
    end
    return incompatible_device_types
end

function construct_services!(
    container::OptimizationContainer,
    sys::PSY.System,
    services_template::ServicesModelContainer,
    devices_template::DevicesModelContainer,
)
    isempty(services_template) && return
    incompatible_device_types = get_incompatible_devices(devices_template)

    function _construct_valid_services!(service_model::ServiceModel)
        @debug "Building $(get_component_type(service_model)) with $(get_formulation(service_model)) formulation"
        services = get_component_type(service_model)[]
        if validate_services!(
            get_component_type(service_model),
            services,
            incompatible_device_types,
            sys,
        )
            construct_service!(
                container,
                services,
                sys,
                service_model,
                devices_template,
                incompatible_device_types,
            )
        end
    end

    groupservice = nothing

    for (key, service_model) in services_template
        if get_formulation(service_model) === GroupReserve  # group service needs to be constructed last
            groupservice = key
            continue
        end
        _construct_valid_services!(service_model)
    end
    groupservice === nothing || _construct_valid_services!(services_template[groupservice])
    return
end

function construct_service!(
    container::OptimizationContainer,
    services::Vector{SR},
    sys::PSY.System,
    model::ServiceModel{SR, RangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.Reserve}
    services_mapping = PSY.get_contributing_device_mapping(sys)
    time_steps = get_time_steps(container)
    names = [PSY.get_name(s) for s in services]

    if built_for_simulation(container)
        add_param_container!(
            container,
            RequirementTimeSeriesParameter("requirement"),
            SR,
            names,
            time_steps,
        )
    end

    add_cons_container!(container, RequirementConstraint(), SR, names, time_steps)

    for service in services
        contributing_devices =
            services_mapping[(type = SR, name = PSY.get_name(service))].contributing_devices
        if !isempty(incompatible_device_types)
            contributing_devices = [
                d for d in contributing_devices if
                typeof(d) ∉ incompatible_device_types && PSY.get_available(d)
            ]
        end
        # Services without contributing devices should have been filtered out in the validation
        @assert !isempty(contributing_devices)
        # Variables
        add_variables!(
            container,
            ActivePowerReserveVariable,
            service,
            contributing_devices,
            RangeReserve(),
        )
        # Constraints
        service_requirement_constraint!(container, service, model)
        modify_device_model!(devices_template, model, contributing_devices)

        # Cost Function
        cost_function!(container, service, model)
    end

    if get_feedforward(model) !== nothing
        feedforward!(optimization_container, PSY.Device[], model, get_feedforward(model))
    end

    return
end

function construct_service!(
    container::OptimizationContainer,
    services::Vector{SR},
    sys::PSY.System,
    model::ServiceModel{SR, StepwiseCostReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.Reserve}
    services_mapping = PSY.get_contributing_device_mapping(sys)
    time_steps = get_time_steps(container)
    names = [PSY.get_name(s) for s in services]
    # Does not use the standard implementation of add_variable!()
    add_variable!(container, ServiceRequirementVariable(), services, StepwiseCostReserve())
    add_cons_container!(container, RequirementConstraint(), SR, names, time_steps)

    for service in services
        contributing_devices =
            services_mapping[(
                type = typeof(service),
                name = PSY.get_name(service),
            )].contributing_devices
        if !isempty(incompatible_device_types)
            contributing_devices = [
                d for d in contributing_devices if
                typeof(d) ∉ incompatible_device_types && PSY.get_available(d)
            ]
        end
        # Variables
        add_variables!(
            container,
            ActivePowerReserveVariable,
            service,
            contributing_devices,
            StepwiseCostReserve(),
        )
        # Constraints
        service_requirement_constraint!(container, service, model)
        modify_device_model!(devices_template, model, contributing_devices)
        # Cost Function
        cost_function!(container, service, model)
    end

    if get_feedforward(model) !== nothing
        feedforward!(optimization_container, PSY.Device[], model, get_feedforward(model))
    end

    return
end

function construct_service!(
    container::OptimizationContainer,
    services::Vector{PSY.AGC},
    sys::PSY.System,
    ::ServiceModel{PSY.AGC, T},
    devices_template::Dict{Symbol, DeviceModel},
    ::Vector{<:DataType},
) where {T <: AbstractAGCFormulation}
    # Order is important in the addition of these variables
    # for device_model in devices_template
    # TODO: make a check for the devices' models
    #end
    agc_areas = [PSY.get_area(agc) for agc in services]
    areas = PSY.get_components(PSY.Area, sys)
    for area in areas
        if area ∉ agc_areas
            #    throw(IS.ConflictingInputsError("All area most have an AGC service assigned in order to model the System's Frequency regulation"))
        end
    end
    add_variables!(container, SteadyStateFrequencyDeviation)
    add_variables!(container, AreaMismatchVariable, areas, T())
    add_variables!(container, SmoothACE, areas, T())
    add_variables!(container, LiftVariable, areas, T())
    add_variables!(container, ActivePowerVariable, areas, T())
    add_variables!(container, DeltaActivePowerUpVariable, areas, T())
    add_variables!(container, DeltaActivePowerDownVariable, areas, T())
    # add_variables!(container, AdditionalDeltaActivePowerUpVariable, areas)
    # add_variables!(container, AdditionalDeltaActivePowerDownVariable, areas)
    balancing_auxiliary_variables!(container, sys)

    absolute_value_lift(container, areas)
    frequency_response_constraint!(container, sys)
    add_initial_condition!(container, services, T(), AreaControlError)
    smooth_ace_pid!(container, services)
    aux_constraints!(container, sys)
end

"""
    Constructs a service for StaticReserveGroup.
"""
function construct_service!(
    container::OptimizationContainer,
    services::Vector{SR},
    ::PSY.System,
    model::ServiceModel{SR, GroupReserve},
    ::Dict{Symbol, DeviceModel},
    ::Vector{<:DataType},
) where {SR <: PSY.StaticReserveGroup}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(s) for s in services]

    add_cons_container!(container, RequirementConstraint(), SR, names, time_steps)

    for service in services
        contributing_services = PSY.get_contributing_services(service)

        # check if variables exist
        check_activeservice_variables(container, contributing_services)
        # Constraints
        service_requirement_constraint!(container, service, model, contributing_services)
    end
    return
end

function construct_service!(
    container::OptimizationContainer,
    services::Vector{SR},
    sys::PSY.System,
    model::ServiceModel{SR, RampReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.Reserve}
    services_mapping = PSY.get_contributing_device_mapping(sys)
    time_steps = get_time_steps(container)
    names = [PSY.get_name(s) for s in services]

    if built_for_simulation(container)
        add_param_container!(
            container,
            RequirementTimeSeriesParameter("requirement"),
            SR,
            names,
            time_steps,
        )
    end

    add_cons_container!(container, RequirementConstraint(), SR, names, time_steps)

    for service in services
        contributing_devices =
            services_mapping[(
                type = typeof(service),
                name = PSY.get_name(service),
            )].contributing_devices
        if !isempty(incompatible_device_types)
            contributing_devices = [
                d for d in contributing_devices if
                typeof(d) ∉ incompatible_device_types && PSY.get_available(d)
            ]
        end
        # Variables
        add_variables!(
            container,
            ActivePowerReserveVariable,
            service,
            contributing_devices,
            RampReserve(),
        )
        # Constraints
        service_requirement_constraint!(container, service, model)
        ramp_constraints!(container, service, contributing_devices, model)
        modify_device_model!(devices_template, model, contributing_devices)

        # Cost Function
        cost_function!(container, service, model)
    end
    return
end
