function get_incompatible_devices(
    devices_template::Dict,
    ::Type{U},
) where {U <: PSY.Service}
    incompatible_device_types = Set{DataType}()
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

# Unlike most services, AGC is compatible with FixedOutput
function get_incompatible_devices(::Dict, ::Type{PSY.AGC})
    return Set{DataType}()
end

function construct_services!(
    container::OptimizationContainer,
    sys::PSY.System,
    stage::ArgumentConstructStage,
    services_template::ServicesModelContainer,
    devices_template::DevicesModelContainer,
    network_model::NetworkModel{<:PM.AbstractPowerModel},
)
    isempty(services_template) && return
    groupservice = nothing
    for (key, service_model) in services_template
        service_type = get_component_type(service_model)
        incompatible_device_types = get_incompatible_devices(devices_template, service_type)
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
            network_model,
        )
    end
    groupservice === nothing || construct_service!(
        container,
        sys,
        stage,
        services_template[groupservice],
        devices_template,
        incompatible_device_types,
        network_model,
    )
    return
end

function construct_services!(
    container::OptimizationContainer,
    sys::PSY.System,
    stage::ModelConstructStage,
    services_template::ServicesModelContainer,
    devices_template::DevicesModelContainer,
    network_model::NetworkModel{<:PM.AbstractPowerModel},
)
    isempty(services_template) && return
    groupservice = nothing
    for (key, service_model) in services_template
        service_type = get_component_type(service_model)
        incompatible_device_types = get_incompatible_devices(devices_template, service_type)
        if get_formulation(service_model) === GroupReserve  # group service needs to be constructed last
            groupservice = key
            continue
        end
        isempty(get_contributing_devices_map(service_model)) && continue
        construct_service!(
            container,
            sys,
            stage,
            service_model,
            devices_template,
            incompatible_device_types,
            network_model,
        )
    end
    groupservice === nothing || construct_service!(
        container,
        sys,
        stage,
        services_template[groupservice],
        devices_template,
        incompatible_device_types,
        network_model,
    )
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, RangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    add_parameters!(container, RequirementTimeSeriesParameter, service, model)
    contributing_devices = get_contributing_devices(model)

    add_variables!(
        container,
        ActivePowerReserveVariable,
        service,
        contributing_devices,
        RangeReserve(),
    )
    add_to_expression!(container, ActivePowerReserveVariable, model, devices_template)
    add_feedforward_arguments!(container, model, service)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, RangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    contributing_devices = get_contributing_devices(model)

    add_constraints!(container, RequirementConstraint, service, contributing_devices, model)
    add_constraints!(
        container,
        ParticipationFractionConstraint,
        service,
        contributing_devices,
        model,
    )
    objective_function!(container, service, model)

    add_feedforward_constraints!(container, model, service)

    add_constraint_dual!(container, sys, model)

    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, RangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.ConstantReserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    contributing_devices = get_contributing_devices(model)

    add_variables!(
        container,
        ActivePowerReserveVariable,
        service,
        contributing_devices,
        RangeReserve(),
    )
    add_to_expression!(container, ActivePowerReserveVariable, model, devices_template)
    add_feedforward_arguments!(container, model, service)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, RangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.ConstantReserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    contributing_devices = get_contributing_devices(model)

    add_constraints!(container, RequirementConstraint, service, contributing_devices, model)
    add_constraints!(
        container,
        ParticipationFractionConstraint,
        service,
        contributing_devices,
        model,
    )
    objective_function!(container, service, model)

    add_feedforward_constraints!(container, model, service)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, StepwiseCostReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    contributing_devices = get_contributing_devices(model)
    add_variable!(container, ServiceRequirementVariable(), service, StepwiseCostReserve())
    add_variables!(
        container,
        ActivePowerReserveVariable,
        service,
        contributing_devices,
        StepwiseCostReserve(),
    )
    add_to_expression!(container, ActivePowerReserveVariable, model, devices_template)
    add_expressions!(container, ProductionCostExpression, [service], model)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, StepwiseCostReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    contributing_devices = get_contributing_devices(model)

    add_constraints!(container, RequirementConstraint, service, contributing_devices, model)

    objective_function!(container, service, model)

    add_feedforward_constraints!(container, model, service)

    add_constraint_dual!(container, sys, model)
    return
end


function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{S, T},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {S <: PSY.AGC, T <: AbstractAGCFormulation}
    @error "TODO - implement version for copper plate"
end 

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{S, T},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:AreaPTDFPowerModel},
) where {S <: PSY.AGC, T <: AbstractAGCFormulation}
    services = get_available_components(model, sys)
    agc_areas = PSY.get_area.(services)
    areas = PSY.get_components(PSY.Area, sys)
    if !isempty(setdiff(areas, agc_areas))
        throw(
            IS.ConflictingInputsError(
                "All area must have an AGC service assigned in order to model the System's Frequency regulation",
            ),
        )
    end
    interchanges = get_available_components(PSY.AreaInterchange, sys)
    add_variables!(container, ScheduledFlowActivePowerVariable, interchanges)
    add_variables!(container, SteadyStateFrequencyDeviation)
    add_variables!(container, ActivePowerImbalance)
    add_variables!(container, SmoothACE, services, T())
    add_variables!(container, AreaMismatchVariable, services, T())
    add_variables!(container, LiftVariable, services, T())

    # Add device level variables:
    contributing_devices = get_contributing_devices(model)
    add_variables!(
        container,
        DeltaActivePowerUpVariable,
        contributing_devices,
        T(),
    )
    add_variables!(
        container,
        DeltaActivePowerDownVariable,
        contributing_devices,
        T(),
    )
    add_variables!(
        container,
        AdditionalDeltaActivePowerUpVariable,
        contributing_devices,
        T(),
    )
    add_variables!(
        container,
        AdditionalDeltaActivePowerDownVariable,
        contributing_devices,
        T(),
    )
    #Add device level variables to the active power balance
    add_to_expression!(
        container, 
        ActivePowerBalance,
        DeltaActivePowerUpVariable,
        contributing_devices,
        model,
        network_model,
    )
    add_to_expression!(
        container, 
        ActivePowerBalance,
        DeltaActivePowerDownVariable,
        contributing_devices,
        model,
        network_model,
    )
        add_to_expression!(
        container, 
        ActivePowerBalance,
        AdditionalDeltaActivePowerUpVariable,
        contributing_devices,
        model,
        network_model,
    )
    add_to_expression!(
        container, 
        ActivePowerBalance,
        AdditionalDeltaActivePowerDownVariable,
        contributing_devices,
        model,
        network_model,
    )

    # Build area level expressions from device level variables:
    area_device_map = _build_area_device_map(contributing_devices)
    add_to_expression!(
        container,
        DeltaActivePowerUpExpression,
        DeltaActivePowerUpVariable,
        areas,
        contributing_devices,
        area_device_map,
        model,
    )
    #Should no longer need this if we add them at the device level:
    add_to_expression!(
        container,
        ActivePowerBalance,
        DeltaActivePowerUpVariable,
        areas,
        contributing_devices,
        area_device_map,
        model,
    ) 
    add_to_expression!(
        container,
        DeltaActivePowerDownExpression,
        DeltaActivePowerDownVariable,
        areas,
        contributing_devices,
        area_device_map,
        model,
    )
    #Should no longer need this if we add them at the device level:
    add_to_expression!(
        container,
        ActivePowerBalance,
        DeltaActivePowerDownVariable,
        areas,
        contributing_devices,
        area_device_map,
        model,
    ) 
    add_to_expression!(
        container,
        AdditionalDeltaActivePowerUpExpression,
        AdditionalDeltaActivePowerUpVariable,
        areas,
        contributing_devices,
        area_device_map,
        model,
    )
    #Should no longer need this if we add them at the device level:
    add_to_expression!(
        container,
        ActivePowerBalance,
        AdditionalDeltaActivePowerUpVariable,
        areas,
        contributing_devices,
        area_device_map,
        model,
    ) 
    add_to_expression!(
        container,
        AdditionalDeltaActivePowerDownExpression,
        AdditionalDeltaActivePowerDownVariable,
        areas,
        contributing_devices,
        area_device_map,
        model,
    )
    #Should no longer need this if we add them at the device level:
    add_to_expression!(
        container,
        ActivePowerBalance,
        AdditionalDeltaActivePowerDownVariable,
        areas,
        contributing_devices,
        area_device_map,
        model,
    ) 

    add_initial_condition!(container, services, T(), AreaControlError())

    add_to_expression!(container, RawACE, SteadyStateFrequencyDeviation, services, model)
    add_feedforward_arguments!(container, model, services)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{PSY.AGC, PIDSmoothACE},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
)
    # Device level constraints:
    devices = get_contributing_devices(model)
    services = get_available_components(model, sys)


    interchanges = get_available_components(PSY.AreaInterchange, sys)
    agc_interchange_map = _build_agc_interchange_map(services, interchanges)
    add_to_expression!(container, RawACE, FlowActivePowerVariable, services, model, agc_interchange_map)   

    # Second part of Eqs. (22), (23):
    add_constraints!(
        container,
        RegulationLimitsConstraint,
        DeltaActivePowerUpVariable,
        devices,
        model,
        network_model,
    )
    # Eq. (24):
    add_constraints!(container, RampLimitConstraint, devices, model, network_model)

    area_device_map = _build_area_device_map(devices)
    # Eqs. (18), (19):
    add_constraints!(
        container,
        ParticipationAssignmentConstraint,
        devices,
        model,
        network_model,
        area_device_map,
    )

    # Area/AGC level constraints: 
    services = get_available_components(model, sys)
    # Eqs (6), (7)
    add_constraints!(
        container,
        SACEPIDAreaConstraint,
        SteadyStateFrequencyDeviation,
        services,
        model,
        sys,
    )

    # Replacing absolute value constraint. 
    add_constraints!(container, AbsoluteValueConstraint, LiftVariable, services, model)
    # Eqs (17)
    add_constraints!(container, BalanceAuxConstraint, SmoothACE, services, model, sys)

    add_constraints!(
        container,
        CopperPlateImbalanceConstraint,
        services,
        model,
        sys,
    ) 

    # Eqs. (4), (5)
    add_constraints!(
        container,
        FrequencyResponseConstraint,
        SteadyStateFrequencyDeviation,
        services,
        model,
        sys,
    )

    add_feedforward_constraints!(container, model, services)
    add_constraint_dual!(container, sys, model)
    objective_function!(container, devices, model)  # add cost of emergency reserve per generator
    objective_function!(container, services, model) # add cost of system slack and    
    return
end


function _build_area_device_map(contributing_devices::Vector{T}) where {T <: PSY.Generator}
    area_device_map = Dict{String, Vector{PSY.Generator}}()
    for device in contributing_devices
        area_name = PSY.get_name(PSY.get_area(PSY.get_bus(device)))
        area_devices = get!(area_device_map, area_name, Vector{PSY.Generator}())
        push!(area_devices, device)
    end
    return area_device_map
end

function _build_agc_interchange_map(agcs, area_interchanges)
    area_to_agc_map = Dict{String, String}()
    for agc in agcs
        agc_name = PSY.get_name(agc)
        area_name = PSY.get_name(PSY.get_area(agc))
        area_to_agc_map[area_name] = agc_name 
    end 
    agc_interchange_map = Dict{String, Dict{Symbol, Vector{PSY.AreaInterchange}}}()
    for area_interchange in area_interchanges
        from_area_name = PSY.get_name(PSY.get_from_area(area_interchange))
        from_agc_name = area_to_agc_map[from_area_name]
        from_area_map = get!(agc_interchange_map, from_agc_name, Dict{Symbol, Vector{PSY.AreaInterchange}}(:from_areas => Vector{PSY.AreaInterchange}(), :to_areas => Vector{PSY.AreaInterchange}() ))
        push!(from_area_map[:from_areas], area_interchange)

        to_area_name = PSY.get_name(PSY.get_to_area(area_interchange))
        to_agc_name = area_to_agc_map[to_area_name]
        to_area_map = get!(agc_interchange_map, to_agc_name, Dict{Symbol, Vector{PSY.AreaInterchange}}(:from_areas => Vector{PSY.AreaInterchange}(), :to_areas => Vector{PSY.AreaInterchange}() ))
        push!(to_area_map[:to_areas], area_interchange)
    end 
    return agc_interchange_map
end 
"""
    Constructs a service for ConstantReserveGroup.
"""
function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, GroupReserve},
    ::Dict{Symbol, DeviceModel},
    ::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.ConstantReserveGroup}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
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
    ::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.ConstantReserveGroup}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    contributing_services = PSY.get_contributing_services(service)

    add_constraints!(
        container,
        RequirementConstraint,
        service,
        contributing_services,
        model,
    )

    add_constraint_dual!(container, sys, model)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, RampReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    contributing_devices = get_contributing_devices(model)
    add_parameters!(container, RequirementTimeSeriesParameter, service, model)

    add_variables!(
        container,
        ActivePowerReserveVariable,
        service,
        contributing_devices,
        RampReserve(),
    )
    add_to_expression!(container, ActivePowerReserveVariable, model, devices_template)
    add_feedforward_arguments!(container, model, service)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, RampReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    contributing_devices = get_contributing_devices(model)

    add_constraints!(container, RequirementConstraint, service, contributing_devices, model)
    add_constraints!(container, RampConstraint, service, contributing_devices, model)
    add_constraints!(
        container,
        ParticipationFractionConstraint,
        service,
        contributing_devices,
        model,
    )

    objective_function!(container, service, model)

    add_feedforward_constraints!(container, model, service)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, NonSpinningReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.ReserveNonSpinning}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    contributing_devices = get_contributing_devices(model)
    add_parameters!(container, RequirementTimeSeriesParameter, service, model)

    add_variables!(
        container,
        ActivePowerReserveVariable,
        service,
        contributing_devices,
        NonSpinningReserve(),
    )
    add_feedforward_arguments!(container, model, service)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, NonSpinningReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.ReserveNonSpinning}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    contributing_devices = get_contributing_devices(model)

    add_constraints!(container, RequirementConstraint, service, contributing_devices, model)
    add_constraints!(
        container,
        ReservePowerConstraint,
        service,
        contributing_devices,
        model,
    )

    add_constraints!(
        container,
        ParticipationFractionConstraint,
        service,
        contributing_devices,
        model,
    )

    objective_function!(container, service, model)

    add_feedforward_constraints!(container, model, service)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{T, ConstantMaxInterfaceFlow},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: PSY.TransmissionInterface}
    interfaces = get_available_components(model, sys)
    interface = PSY.get_component(T, sys, get_service_name(model))
    if get_use_slacks(model)
        # Adding the slacks can be done in a cleaner fashion
        @assert PSY.get_available(interface)
        transmission_interface_slacks!(container, interface)
    end
    # Lazy container addition for the expressions.
    lazy_container_addition!(
        container,
        InterfaceTotalFlow(),
        T,
        PSY.get_name.(interfaces),
        get_time_steps(container),
    )

    add_feedforward_arguments!(container, model, interface)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{PSY.TransmissionInterface, ConstantMaxInterfaceFlow},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{AreaBalancePowerModel},
)
    interfaces = get_available_components(model, sys)
    interface = PSY.get_component(PSY.TransmissionInterface, sys, get_service_name(model))
    if get_use_slacks(model)
        # Adding the slacks can be done in a cleaner fashion
        @assert PSY.get_available(interface)
        transmission_interface_slacks!(container, interface)
    end
    # Lazy container addition for the expressions.
    lazy_container_addition!(
        container,
        InterfaceTotalFlow(),
        PSY.TransmissionInterface,
        PSY.get_name.(interfaces),
        get_time_steps(container),
    )
    @warn "AreaBalancePowerModel doesn't model individual line flows and it ignores the flows on AC Transmission Devices"
    add_feedforward_arguments!(container, model, interface)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{PSY.TransmissionInterface, ConstantMaxInterfaceFlow},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
)
    name = get_service_name(model)
    service = PSY.get_component(PSY.TransmissionInterface, sys, name)
    !PSY.get_available(service) && return

    add_to_expression!(
        container,
        InterfaceTotalFlow,
        FlowActivePowerVariable,
        service,
        model,
        network_model,
    )

    if get_use_slacks(model)
        add_to_expression!(
            container,
            InterfaceTotalFlow,
            InterfaceFlowSlackUp,
            service,
            model,
        )
        add_to_expression!(
            container,
            InterfaceTotalFlow,
            InterfaceFlowSlackDown,
            service,
            model,
        )
    end

    add_constraints!(container, InterfaceFlowLimit, service, model)
    add_feedforward_constraints!(container, model, service)
    add_constraint_dual!(container, sys, model)
    objective_function!(container, service, model)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{PSY.TransmissionInterface, ConstantMaxInterfaceFlow},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{PTDFPowerModel},
)
    name = get_service_name(model)
    service = PSY.get_component(PSY.TransmissionInterface, sys, name)
    !PSY.get_available(service) && return

    add_to_expression!(
        container,
        InterfaceTotalFlow,
        PTDFBranchFlow,
        service,
        model,
        network_model,
    )

    if get_use_slacks(model)
        add_to_expression!(
            container,
            InterfaceTotalFlow,
            InterfaceFlowSlackUp,
            service,
            model,
        )
        add_to_expression!(
            container,
            InterfaceTotalFlow,
            InterfaceFlowSlackDown,
            service,
            model,
        )
    end

    add_constraints!(container, InterfaceFlowLimit, service, model)
    add_feedforward_constraints!(container, model, service)
    add_constraint_dual!(container, sys, model)
    objective_function!(container, service, model)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{PSY.TransmissionInterface, ConstantMaxInterfaceFlow},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{AreaPTDFPowerModel},
)
    name = get_service_name(model)
    service = PSY.get_component(PSY.TransmissionInterface, sys, name)
    !PSY.get_available(service) && return

    # This function makes interfaces for the AC Branches
    add_to_expression!(
        container,
        InterfaceTotalFlow,
        PTDFBranchFlow,
        service,
        model,
        network_model,
    )

    # This function makes interfaces for the interchanges
    add_to_expression!(
        container,
        InterfaceTotalFlow,
        FlowActivePowerVariable,
        service,
        model,
        network_model,
    )

    if get_use_slacks(model)
        add_to_expression!(
            container,
            InterfaceTotalFlow,
            InterfaceFlowSlackUp,
            service,
            model,
        )
        add_to_expression!(
            container,
            InterfaceTotalFlow,
            InterfaceFlowSlackDown,
            service,
            model,
        )
    end

    add_constraints!(container, InterfaceFlowLimit, service, model)
    add_feedforward_constraints!(container, model, service)
    add_constraint_dual!(container, sys, model)
    objective_function!(container, service, model)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{PSY.TransmissionInterface, VariableMaxInterfaceFlow},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:AbstractPTDFModel},
)
    name = get_service_name(model)
    service = PSY.get_component(PSY.TransmissionInterface, sys, name)
    !PSY.get_available(service) && return

    # This function makes interfaces for the AC Branches
    add_to_expression!(
        container,
        InterfaceTotalFlow,
        PTDFBranchFlow,
        service,
        model,
        network_model,
    )

    if get_use_slacks(model)
        add_to_expression!(
            container,
            InterfaceTotalFlow,
            InterfaceFlowSlackUp,
            service,
            model,
        )
        add_to_expression!(
            container,
            InterfaceTotalFlow,
            InterfaceFlowSlackDown,
            service,
            model,
        )
    end

    add_constraints!(container, InterfaceFlowLimit, service, model)
    add_feedforward_constraints!(container, model, service)
    add_constraint_dual!(container, sys, model)
    objective_function!(container, service, model)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{PSY.TransmissionInterface, U},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{T},
) where {
    T <: PM.AbstractPowerModel,
    U <: Union{ConstantMaxInterfaceFlow, VariableMaxInterfaceFlow},
}
    error("TransmissionInterface models not implemented for PowerModel of type $T")
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{PSY.TransmissionInterface, VariableMaxInterfaceFlow},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
)
    interfaces = get_available_components(model, sys)
    if get_use_slacks(model)
        # Adding the slacks can be done in a cleaner fashion
        interface =
            PSY.get_component(PSY.TransmissionInterface, sys, get_service_name(model))
        @assert PSY.get_available(interface)
        transmission_interface_slacks!(container, interface)
    end
    # Lazy container addition for the expressions.
    lazy_container_addition!(
        container,
        InterfaceTotalFlow(),
        PSY.TransmissionInterface,
        PSY.get_name.(interfaces),
        get_time_steps(container),
    )
    has_ts = PSY.has_time_series.(interfaces)
    if any(has_ts) && !all(has_ts)
        error(
            "Not all TransmissionInterfaces devices have time series. Check data to complete (or remove) time series.",
        )
    end
    if all(has_ts)
        for device in interfaces
            name = PSY.get_name(device)
            num_ts = length(unique(PSY.get_name.(PSY.get_time_series_keys(device))))
            if num_ts < 2
                error(
                    "TransmissionInterface $name has less than two time series. It is required to add both min_flow and max_flow time series.",
                )
            end
            add_parameters!(container, MinInterfaceFlowLimitParameter, device, model)
            add_parameters!(container, MaxInterfaceFlowLimitParameter, device, model)
        end
    end
    interface = PSY.get_component(PSY.TransmissionInterface, sys, get_service_name(model))
    add_feedforward_arguments!(container, model, interface)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{PSY.TransmissionInterface, U},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {U <: Union{ConstantMaxInterfaceFlow, VariableMaxInterfaceFlow}}
    name = get_service_name(model)
    service = PSY.get_component(PSY.TransmissionInterface, sys, name)
    !PSY.get_available(service) && return

    add_to_expression!(
        container,
        InterfaceTotalFlow,
        FlowActivePowerVariable,
        service,
        model,
        network_model,
    )

    if get_use_slacks(model)
        add_to_expression!(
            container,
            InterfaceTotalFlow,
            InterfaceFlowSlackUp,
            service,
            model,
        )
        add_to_expression!(
            container,
            InterfaceTotalFlow,
            InterfaceFlowSlackDown,
            service,
            model,
        )
    end

    add_constraints!(container, InterfaceFlowLimit, service, model)
    add_feedforward_constraints!(container, model, service)
    add_constraint_dual!(container, sys, model)
    objective_function!(container, service, model)
    return
end
