function _get_scuc_generators(
    devices_template::Dict{Symbol, DeviceModel}, 
    sys::PSY.System,
    ::Type{PSY.ThermalGen},
    )

    valid_devices = get_available_components(
        d -> PSY.get_available(d) && get_formulation(devices_template[Symbol(typeof(d))]) <: ThermalSecurityConstrainedUnitCommitmentWithReserves,
        PSY.ThermalGen,
        sys,
    )
    return valid_devices
end

function add_reserve_security_constraints!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::ServiceModel{SR, R},
    ::SR,
    ::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    ::Dict{Symbol, DeviceModel},
    ::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.Reserve, R <: AbstractReservesFormulation, U <: PSY.Device}

    return
end

function add_reserve_security_constraints!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, R},
    service::SR,
    contributing_devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {SR <: PSY.Reserve{PSY.ReserveUp}, R <: AbstractReservesFormulation, U <: PSY.Device}
    # Add the PostContingencyActivePowerReserveDeployedVariable for the single outage generators
    single_outage_generators = []
    valid_outages = _get_all_scuc_valid_outages(sys, PSY.ThermalGen, network_model)
    generators = _get_scuc_generators(devices_template, sys, PSY.ThermalGen)
    if !isempty(valid_outages)
        single_outage_generators = _get_all_single_outage_generators_by_type(sys, valid_outages, generators)
    end
    contingencies = get_attribute(model, "contingencies")
    instances = []
    if !(isnothing(contingencies)) && !(isempty(contingencies))
        instances = get_available_components(
            d -> PSY.get_name(d) ∈ contingencies,
            PSY.ThermalGen,
            sys,
        )
    end

    single_outage_generators = collect(intersect(single_outage_generators, instances))

    contributing_generators = collect(intersect(contributing_devices, generators))

    if !isempty(single_outage_generators)
        add_variables!(
            container,
            PostContingencyActivePowerReserveDeployedVariable,
            service,
            contributing_generators,
            single_outage_generators,
            R(),
        )
    end
end

function add_reserve_security_constraints!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::ServiceModel{SR, R},
    ::SR,
    ::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    ::Dict{Symbol, DeviceModel},
    ::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.Reserve, R <: AbstractReservesFormulation, U <: PSY.Device}

    return
end

function add_reserve_security_constraints!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, R},
    service::SR,
    contributing_devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {SR <: PSY.Reserve{PSY.ReserveUp}, R <: AbstractReservesFormulation, U <: PSY.Device}
    # Add the PostContingencyActivePowerReserveDeployedVariable for the single outage generators
    single_outage_generators = []
    generators = _get_scuc_generators(devices_template, sys, PSY.ThermalGen)
    valid_outages = _get_all_scuc_valid_outages(sys, PSY.Generator, network_model)
    if !isempty(valid_outages)
        single_outage_generators = _get_all_single_outage_generators_by_type(sys, valid_outages, generators)
    end

    contingencies = get_attribute(model, "contingencies")
    instances = []
    if !(isnothing(contingencies)) && !(isempty(contingencies))
        instances = get_available_components(
            d -> PSY.get_name(d) ∈ contingencies,
            PSY.ThermalGen,
            sys,
        )
    end

    single_outage_generators = collect(intersect(single_outage_generators, instances))

    contributing_generators = collect(intersect(contributing_devices, generators))

    branches = _get_reduced_network_branches(sys, network_model)

    if !isempty(single_outage_generators)
        add_constraints!(
            container,
            PostContingencyReserveDeploymentLimitConstraint,
            service,
            contributing_generators,
            single_outage_generators,
            model,
        )
        add_constraints!(
            container,
            PostContingencyReserveDeploymentBalanceConstraint,
            service,
            contributing_generators,
            single_outage_generators,
            model,
        )
        # Add the post contingency branch G-1 security constrained branch flow expresssion and constraints
        # here since they depend on the service models and the branch models
        add_to_expression!(
            container,
            PTDFPostContingencyBranchFlowWithReserves,
            FlowActivePowerVariable,
            service,
            branches,
            contributing_generators,
            single_outage_generators,
            model,
            network_model,
        )

        add_constraints!(
            container,
            PostContingencyRateLimitConstraintWithReserves,
            service,
            branches,
            contributing_generators,
            single_outage_generators,
            model,
            network_model,
        )

    end
end
