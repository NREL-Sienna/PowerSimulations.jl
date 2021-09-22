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

function map_contributing_devices_by_type!(
    service_model::ServiceModel,
    contributing_devices,
)
    types = unique(typeof.(contributing_devices))
    for S in types
        _devices = filter(x -> typeof(x) == S, contributing_devices)
        add_contributing_devices_map!(service_model, S, _devices)
    end
    return
end

function populate_aggregated_service_model!(template, sys::PSY.System)
    services_template = get_service_models(template)
    for (key, service_model) in services_template
        attributes = get_attributes(service_model)
        if get(attributes, "aggregated_service_model", false)
            delete!(services_template, key)
            D = get_component_type(service_model)
            B = get_formulation(service_model)
            for service in PSY.get_components(D, sys)
                new_key = (PSY.get_name(service), Symbol(D))
                if !haskey(services_template, new_key)
                    set_service_model!(template, ServiceModel(D, B, PSY.get_name(service)))
                end
            end
        end
    end
    return
end

function populate_contributing_devices!(template, sys::PSY.System)
    service_models = get_service_models(template)
    isempty(service_models) && return

    device_models = get_device_models(template)
    incompatible_device_types = get_incompatible_devices(device_models)
    services_mapping = PSY.get_contributing_device_mapping(sys)
    for (service_key, service_model) in service_models
        S = get_component_type(service_model)
        service = PSY.get_component(S, sys, get_service_name(service_model))
        if isnothing(service)
            @warn "The data doesn't include services of type $(S) and name $(get_service_name(service_model)), consider changing the service models" _group =
                :ConstructGroup
            continue
        end
        contributing_devices_ =
            services_mapping[(type = S, name = PSY.get_name(service))].contributing_devices
        contributing_devices = [
            d for d in contributing_devices_ if
            typeof(d) ∉ incompatible_device_types && PSY.get_available(d)
        ]
        if isempty(contributing_devices)
            @warn "The contributing devices for service $(PSY.get_name(service)) is empty, consider removing the service from the system" _group =
                :ConstructGroup
            continue
        end
        map_contributing_devices_by_type!(service_model, contributing_devices)
    end
    return
end

function construct_services!(
    container::OptimizationContainer,
    sys::PSY.System,
    stage::ArgumentConstructStage,
    services_template::ServicesModelContainer,
    devices_template::DevicesModelContainer,
)
    isempty(services_template) && return
    incompatible_device_types = get_incompatible_devices(devices_template)

    groupservice = nothing

    for (key, service_model) in services_template
        if get_formulation(service_model) === GroupReserve  # group service needs to be constructed last
            groupservice = key
            continue
        end
        isempty(get_contributing_devices(service_model)) && continue
        construct_service!(
            container,
            sys,
            stage,
            service_model,
            devices_template,
            incompatible_device_types,
        )
    end
    groupservice === nothing || construct_service!(
        container,
        sys,
        stage,
        services_template[groupservice],
        devices_template,
        incompatible_device_types,
    )
    return
end

function construct_services!(
    container::OptimizationContainer,
    sys::PSY.System,
    stage::ModelConstructStage,
    services_template::ServicesModelContainer,
    devices_template::DevicesModelContainer,
)
    isempty(services_template) && return
    incompatible_device_types = get_incompatible_devices(devices_template)

    groupservice = nothing
    for (key, service_model) in services_template
        if get_formulation(service_model) === GroupReserve  # group service needs to be constructed last
            groupservice = key
            continue
        end
        isempty(get_contributing_devices(service_model)) && continue
        construct_service!(
            container,
            sys,
            stage,
            service_model,
            devices_template,
            incompatible_device_types,
        )
    end
    groupservice === nothing || construct_service!(
        container,
        sys,
        stage,
        services_template[groupservice],
        devices_template,
        incompatible_device_types,
    )
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, RangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    add_parameters!(container, RequirementTimeSeriesParameter, service, model)
    contributing_devices = get_contributing_devices(model)

    # Variables
    add_variables!(
        container,
        ActivePowerReserveVariable,
        service,
        contributing_devices,
        RangeReserve(),
    )
    add_to_expression!(container, ActivePowerReserveVariable, model, devices_template)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, RangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    contributing_devices = get_contributing_devices(model)

    # Constraints
    add_constraints!(container, RequirementConstraint, service, contributing_devices, model)
    # Cost Function
    cost_function!(container, service, model)

    if get_feedforward(model) !== nothing
        feedforward!(optimization_container, PSY.Device[], model, get_feedforward(model))
    end

    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, RangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.StaticReserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    contributing_devices = get_contributing_devices(model)

    # Variables
    add_variables!(
        container,
        ActivePowerReserveVariable,
        service,
        contributing_devices,
        RangeReserve(),
    )
    add_to_expression!(container, ActivePowerReserveVariable, model, devices_template)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, RangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.StaticReserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    contributing_devices = get_contributing_devices(model)

    # Constraints
    add_constraints!(container, RequirementConstraint, service, contributing_devices, model)

    # Cost Function
    cost_function!(container, service, model)

    if get_feedforward(model) !== nothing
        feedforward!(optimization_container, PSY.Device[], model, get_feedforward(model))
    end

    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, StepwiseCostReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    contributing_devices = get_contributing_devices(model)
    add_variable!(container, ServiceRequirementVariable(), [service], StepwiseCostReserve())
    add_variables!(
        container,
        ActivePowerReserveVariable,
        service,
        contributing_devices,
        StepwiseCostReserve(),
    )
    add_to_expression!(container, ActivePowerReserveVariable, model, devices_template)
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, StepwiseCostReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    contributing_devices = get_contributing_devices(model)

    # Constraints
    add_constraints!(container, RequirementConstraint, service, contributing_devices, model)

    # Cost Function
    cost_function!(container, service, model)

    if get_feedforward(model) !== nothing
        feedforward!(optimization_container, PSY.Device[], model, get_feedforward(model))
    end
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{S, T},
    devices_template::Dict{Symbol, DeviceModel},
    ::Vector{<:DataType},
) where {S <: PSY.AGC, T <: AbstractAGCFormulation}
    name = get_service_name(model)
    service = PSY.get_component(S, sys, name)
    agc_area = PSY.get_area(service)
    areas = PSY.get_components(PSY.Area, sys)
    for area in areas
        if area != agc_area
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

    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{S, T},
    devices_template::Dict{Symbol, DeviceModel},
    ::Vector{<:DataType},
) where {S <: PSY.AGC, T <: AbstractAGCFormulation}
    name = get_service_name(model)
    service = PSY.get_component(S, sys, name)
    agc_area = PSY.get_area(service)
    areas = PSY.get_components(PSY.Area, sys)

    absolute_value_lift(container, areas)
    frequency_response_constraint!(container, sys)
    add_initial_condition!(container, [service], T(), AreaControlError)
    smooth_ace_pid!(container, [service])
    aux_constraints!(container, sys)

    if get_feedforward(model) !== nothing
        feedforward!(optimization_container, PSY.Device[], model, get_feedforward(model))
    end

    return
end

"""
    Constructs a service for StaticReserveGroup.
"""
function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, GroupReserve},
    ::Dict{Symbol, DeviceModel},
    ::Vector{<:DataType},
) where {SR <: PSY.StaticReserveGroup}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    contributing_services = PSY.get_contributing_services(service)
    # check if variables exist
    check_activeservice_variables(container, contributing_services)

    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, GroupReserve},
    ::Dict{Symbol, DeviceModel},
    ::Vector{<:DataType},
) where {SR <: PSY.StaticReserveGroup}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    contributing_services = PSY.get_contributing_services(service)
    # Constraints
    add_constraints!(
        container,
        RequirementConstraint,
        service,
        contributing_services,
        model,
    )

    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, RampReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    contributing_devices = get_contributing_devices(model)
    add_parameters!(container, RequirementTimeSeriesParameter, service, model)

    # Variables
    add_variables!(
        container,
        ActivePowerReserveVariable,
        service,
        contributing_devices,
        RampReserve(),
    )
    add_to_expression!(container, ActivePowerReserveVariable, model, devices_template)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, RampReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    contributing_devices = get_contributing_devices(model)

    # Constraints
    add_constraints!(container, RequirementConstraint, service, contributing_devices, model)
    add_constraints!(container, RampConstraint, service, contributing_devices, model)

    # Cost Function
    cost_function!(container, service, model)

    if get_feedforward(model) !== nothing
        feedforward!(optimization_container, PSY.Device[], model, get_feedforward(model))
    end
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, NonSpinningReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.ReserveNonSpinning}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    contributing_devices = get_contributing_devices(model)
    add_parameters!(container, RequirementTimeSeriesParameter, service, model)

    # Variables
    add_variables!(
        container,
        ActivePowerReserveVariable,
        service,
        contributing_devices,
        NonSpinningReserve(),
    )

    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, NonSpinningReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.ReserveNonSpinning}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    contributing_devices = get_contributing_devices(model)

    # Constraints
    add_constraints!(container, RequirementConstraint, service, contributing_devices, model)
    add_constraints!(
        container,
        ReservePowerConstraint,
        service,
        contributing_devices,
        model,
    )

    # Cost Function
    cost_function!(container, service, model)

    if get_feedforward(model) !== nothing
        feedforward!(optimization_container, PSY.Device[], model, get_feedforward(model))
    end
    return
end
