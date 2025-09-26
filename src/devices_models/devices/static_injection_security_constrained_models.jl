function add_variables!(
    container::OptimizationContainer,
    sys::PSY.System,
    var_type::Type{T},
    devices::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    formulation::AbstractSecurityConstrainedUnitCommitment,
) where {
    T <: PostContingencyActivePowerChangeVariable,
    D <: PSY.ThermalGen,
}
    time_steps = get_time_steps(container)
    binary = get_variable_binary(T(), D, formulation)
    settings = get_settings(container)

    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )

    associated_outages = unique([outage for (_, outage) in generator_outages_pairs])

    variable = add_variable_container!(
        container,
        T(),
        D,
        string.(IS.get_uuid.(associated_outages)),
        [PSY.get_name(d) for d in devices],
        time_steps,
    )

    for outage in associated_outages
        outage_id = string(IS.get_uuid(outage))
        associated_devices =
            PSY.get_associated_components(sys, outage; component_type = PSY.Generator)

        for device in devices
            name = PSY.get_name(device)
            device_is_in_reserve_devices = device in associated_devices

            for t in time_steps
                variable[outage_id, name, t] = JuMP.@variable(
                    get_jump_model(container),
                    base_name = "$(var_type)_$(D)_{$(outage_id), $(name), $(t)}",
                    binary = binary
                )
                if device_is_in_reserve_devices
                    #The device that suffered the outage cannot contribute with reserves deployment for its own contingency.
                    JuMP.set_upper_bound(variable[outage_id, name, t], 0.0)
                    JuMP.set_lower_bound(variable[outage_id, name, t], 0.0)
                    JuMP.set_start_value(variable[outage_id, name, t], 0.0)
                    continue
                end

                # TODO: Contingencies Implement method to get max change depending on the device and formulation
                ub = get_variable_upper_bound(var_type, device, formulation)
                ub !== nothing && JuMP.set_upper_bound(variable[outage_id, name, t], ub)

                lb = get_variable_lower_bound(var_type, device, formulation)
                lb !== nothing && !binary &&
                    JuMP.set_lower_bound(variable[outage_id, name, t], lb)

                if get_warm_start(settings)
                    init = get_variable_warm_start_value(var_type, device, formulation)
                    init !== nothing &&
                        JuMP.set_start_value(variable[outage_id, name, t], init)
                end
            end
        end
    end
    return
end

"""
This function creates the arguments model for a full thermal Security-Constrained dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ThermalGen, D <: AbstractSecurityConstrainedUnitCommitment}
    devices = get_available_components(model, sys)

    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, OnVariable, devices, D())
    add_variables!(container, StartVariable, devices, D())
    add_variables!(container, StopVariable, devices, D())

    add_variables!(container, TimeDurationOn, devices, D())
    add_variables!(container, TimeDurationOff, devices, D())

    initial_conditions!(container, devices, D())

    if haskey(get_time_series_names(model), ActivePowerTimeSeriesParameter)
        add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    end
    if haskey(get_time_series_names(model), FuelCostParameter)
        add_parameters!(container, FuelCostParameter, devices, model)
    end

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )

    add_expressions!(container, ProductionCostExpression, devices, model)
    add_expressions!(container, FuelConsumptionExpression, devices, model)

    add_to_expression!(
        container,
        ActivePowerRangeExpressionLB,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerRangeExpressionUB,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        FuelConsumptionExpression,
        ActivePowerVariable,
        devices,
        model,
    )
    if get_use_slacks(model)
        add_variables!(container, RateofChangeConstraintSlackUp, devices, D())
        add_variables!(container, RateofChangeConstraintSlackDown, devices, D())
    end

    add_feedforward_arguments!(container, model, devices)

    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )

    if isempty(generator_outages_pairs)
        @warn "No associated outage supplemental attributes found associated with Generators. Skipping contingency variables addition for formulation $D."
        return
    end

    add_variables!(
        container,
        sys,
        PostContingencyActivePowerChangeVariable,
        devices,
        D(),
    )

    return
end

"""
This function creates the constraints for the model for a full thermal Security-Constrained dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, D},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ThermalGen, D <: AbstractSecurityConstrainedUnitCommitment}
    devices = get_available_components(model, sys)
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerRangeExpressionLB,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerRangeExpressionUB,
        devices,
        model,
        network_model,
    )

    add_constraints!(container, CommitmentConstraint, devices, model, network_model)
    add_constraints!(container, RampConstraint, devices, model, network_model)
    add_constraints!(container, DurationConstraint, devices, model, network_model)
    if haskey(get_time_series_names(model), ActivePowerTimeSeriesParameter)
        add_constraints!(
            container,
            ActivePowerVariableTimeSeriesLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            network_model,
        )
    end

    add_feedforward_constraints!(container, model, devices)

    objective_function!(container, devices, model, get_network_formulation(network_model))

    add_constraint_dual!(container, sys, model)

    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )

    if isempty(generator_outages_pairs)
        @warn "No associated outage supplemental attributes found associated with Generators. Skipping contingency expresions/constraints addition for formulation $D."
        return
    end

    add_to_expression!(
        container,
        sys,
        PostContingencyActivePowerGeneration,
        ActivePowerVariable,
        PostContingencyActivePowerChangeVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        sys,
        PostContingencyActivePowerVariableLimitsConstraint,
        PostContingencyActivePowerGeneration,
        devices,
        model,
        network_model,
    )

    add_to_expression!(
        container,
        sys,
        PostContingencyActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        sys,
        PostContingencyActivePowerBalance,
        PostContingencyActivePowerChangeVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        sys,
        PostContingencyGenerationBalanceConstraint,
        PostContingencyActivePowerBalance,
        devices,
        model,
        network_model,
    )

    add_to_expression!(
        container,
        sys,
        PostContingencyNodalActivePowerDeployment,
        PostContingencyActivePowerChangeVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        sys,
        PostContingencyNodalActivePowerDeployment,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )

    #ADD EXPRESSION TO CALCULATE POST CONTINGENCY FLOW FOR EACH Branch
    add_to_expression!(
        container,
        sys,
        PostContingencyBranchFlow,
        FlowActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        sys,
        PostContingencyBranchFlow,
        PostContingencyNodalActivePowerDeployment,
        devices,
        model,
        network_model,
    )
    #ADD CONSTRAINT FOR EACH CONTINGENCY: FLOW <= RATE LIMIT
    add_constraints!(
        container,
        sys,
        PostContingencyEmergencyRateLimitConstraint,
        PostContingencyBranchFlow,
        PSY.get_components(PSY.ACTransmission, sys),
        model,
        network_model,
    )

    #ADD RAMPING CONSTRAINTS
    add_constraints!(
        container,
        sys,
        PostContingencyRampConstraint,
        PostContingencyActivePowerChangeVariable,
        devices,
        model,
        network_model;
        service = "",
    )

    return
end

"""
Default implementation to add generators Expressions for Post-Contingency Generation
"""
function add_to_expression!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    ::Type{D},
    generators::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyActivePowerGeneration,
    U <: ActivePowerVariable,
    D <: PostContingencyActivePowerChangeVariable,
    V <: PSY.Generator,
    W <: AbstractSecurityConstrainedUnitCommitment,
    X <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)

    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )
    associated_outages = unique([outage for (_, outage) in generator_outages_pairs])

    expressions =
        lazy_container_addition!(container, T(), V,
            string.(IS.get_uuid.(associated_outages)),
            PSY.get_name.(generators),
            time_steps)

    variable_generator = get_variable(container, U(), V)
    variable_generator_change = get_variable(container, D(), V)

    for generator in generators
        variable_generator = get_variable(container, U(), typeof(generator))
        generator_name = get_name(generator)

        for outage in associated_outages
            associated_devices =
                PSY.get_associated_components(
                    sys,
                    outage;
                    component_type = PSY.Generator,
                )

            generator_is_in_associated_devices = generator in associated_devices # generator_outage == generator

            outage_id = string(IS.get_uuid(outage))

            for t in time_steps
                _add_to_jump_expression!(
                    expressions[outage_id, generator_name, t],
                    variable_generator[generator_name, t],
                    1.0,
                )
                if generator_is_in_associated_devices
                    continue
                end
                _add_to_jump_expression!(
                    expressions[outage_id, generator_name, t],
                    variable_generator_change[outage_id, generator_name, t],
                    1.0,
                )
            end
        end
    end
    return
end

"""
Add post-contingency rate limit constraints for Generators for G-1 formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    device_model::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyActivePowerVariableLimitsConstraint,
    U <: PostContingencyActivePowerGeneration,
    V <: PSY.Generator,
    W <: AbstractSecurityConstrainedUnitCommitment,
    X <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    device_names = PSY.get_name.(devices)
    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )
    associated_outages = unique([outage for (_, outage) in generator_outages_pairs])

    con_lb =
        add_constraints_container!(
            container,
            T(),
            V,
            string.(IS.get_uuid.(associated_outages)),
            device_names,
            time_steps;
            meta = "lb",
        )

    con_ub =
        add_constraints_container!(
            container,
            T(),
            V,
            string.(IS.get_uuid.(associated_outages)),
            device_names,
            time_steps;
            meta = "ub",
        )

    expressions = get_expression(container, U(), V)
    for device in devices
        device_name = get_name(device)

        for outage in associated_outages
            associated_devices =
                PSY.get_associated_components(
                    sys,
                    outage;
                    component_type = PSY.Generator,
                )

            generator_is_in_associated_devices = device in associated_devices # generator_outage == generator

            outage_id = string(IS.get_uuid(outage))
            #TODO HOW WE SHOULD HANDLE THE EXPRESSIONS AND CONSTRAINTS RELATED TO THE OUTAGE OF THE GENERATOR RESPECT TO ITSELF?
            if generator_is_in_associated_devices
                continue
            end

            limits = get_min_max_limits(
                device,
                ActivePowerVariableLimitsConstraint,
                W,
            )

            for t in time_steps
                con_ub[outage_id, device_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[outage_id, device_name, t] <=
                        limits.max)
                con_lb[outage_id, device_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[outage_id, device_name, t] >=
                        limits.min)
            end
        end
    end

    return
end

#TODO check where this should go.
_get_variable_multiplier(
    _::ActivePowerVariable,
    ::Type{<:PSY.Generator},
    ::AbstractSecurityConstrainedUnitCommitment,
) = -1.0 #"_" avoids ambiguity
_get_variable_multiplier(
    _::PostContingencyActivePowerChangeVariable,
    ::Type{<:PSY.Generator},
    ::AbstractSecurityConstrainedUnitCommitment,
) = 1.0

"""
Default implementation to add variables to PostContingencySystemBalanceExpressions for G-1 formulation
"""
function add_to_expression!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    device_model::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyActivePowerBalance,
    U <: VariableType,
    V <: PSY.Generator,
    W <: AbstractSecurityConstrainedUnitCommitment,
    X <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)

    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )
    associated_outages = unique([outage for (_, outage) in generator_outages_pairs])

    expression =
        lazy_container_addition!(container, T(), V,
            string.(IS.get_uuid.(associated_outages)),
            time_steps)

    for (device, outage) in generator_outages_pairs
        # if !(outage in associated_outages)
        #     continue
        # end

        outage_id = string(IS.get_uuid(outage))
        name = PSY.get_name(device)
        variable = get_variable(container, U(), typeof(device))
        mult = _get_variable_multiplier(U(), typeof(device), W())

        for t in time_steps
            _add_to_jump_expression!(
                expression[outage_id, t],
                variable[name, t],
                mult,
            )
        end
    end

    return
end

function add_to_expression!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    device_model::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyActivePowerBalance,
    U <: PostContingencyActivePowerChangeVariable,
    V <: PSY.Generator,
    W <: AbstractSecurityConstrainedUnitCommitment,
    X <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)

    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )
    associated_outages = unique([outage for (_, outage) in generator_outages_pairs])

    expression =
        lazy_container_addition!(container, T(), V,
            string.(IS.get_uuid.(associated_outages)),
            time_steps)

    reserve_deployment_variable = get_variable(container, U(), V)
    mult = _get_variable_multiplier(U(), V, W())

    for outage in associated_outages
        associated_devices =
            PSY.get_associated_components(sys, outage; component_type = PSY.Generator) #Use PSY.Generator To make sure it considers ALL generators associated with the outage instance
        outage_id = string(IS.get_uuid(outage))

        for device in devices
            if device in associated_devices #The contributting device cannot contribute to the reserves deployment if it has the outage
                continue
            end

            name = PSY.get_name(device)

            for t in time_steps
                _add_to_jump_expression!(
                    expression[outage_id, t],
                    reserve_deployment_variable[outage_id, name, t],
                    mult,
                )
            end
        end
    end
end

"""
Add post-contingency Generation Balance Constraints for Generators for G-1 formulation and G-1 with reserves (SecurityConstrainedReservesFormulation)
"""
function add_constraints!(
    container::OptimizationContainer,
    sys::PSY.System,
    cons_type::Type{T},
    ::Type{U},
    devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyGenerationBalanceConstraint,
    U <: PostContingencyActivePowerBalance,
    V <: PSY.Generator,
    W <: AbstractSecurityConstrainedUnitCommitment,
    X <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )
    associated_outages = unique([outage for (_, outage) in generator_outages_pairs])

    expressions = get_expression(container, U(), V)
    constraint =
        add_constraints_container!(
            container,
            T(),
            V,
            string.(IS.get_uuid.(associated_outages)),
            time_steps,
        )

    for t in time_steps, outage in associated_outages
        outage_id = string(IS.get_uuid(outage))
        constraint[outage_id, t] =
            JuMP.@constraint(get_jump_model(container), expressions[outage_id, t] == 0)
    end

    return
end

function add_to_expression!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyNodalActivePowerDeployment,
    U <: PostContingencyActivePowerChangeVariable,
    V <: PSY.Generator,
    W <: AbstractSecurityConstrainedUnitCommitment,
    X <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)

    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )
    associated_outages = unique([outage for (_, outage) in generator_outages_pairs])

    ptdf = get_PTDF_matrix(network_model)
    bus_numbers = PNM.get_bus_axis(ptdf)

    expression = lazy_container_addition!(
        container,
        T(),
        V,
        string.(IS.get_uuid.(associated_outages)),
        bus_numbers,
        time_steps,
    )

    postcontingency_variable = get_variable(container, U(), V)
    mult = _get_variable_multiplier(U(), V, W())
    network_reduction = get_network_reduction(network_model)

    for outage in associated_outages
        associated_devices =
            PSY.get_associated_components(sys, outage; component_type = PSY.Generator) #Use PSY.Generator To make sure it considers ALL generators associated with the outage instance
        outage_id = string(IS.get_uuid(outage))

        for device in devices
            if device in associated_devices #The contributing device cannot contribute to the power deployment if it has the outage
                continue
            end
            name = PSY.get_name(device)
            bus_no = PNM.get_mapped_bus_number(network_reduction, PSY.get_bus(device))

            for t in get_time_steps(container)
                _add_to_jump_expression!(
                    expression[outage_id, bus_no, t],
                    postcontingency_variable[outage_id, name, t],
                    mult,
                )
            end
        end
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyNodalActivePowerDeployment,
    U <: ActivePowerVariable,
    V <: PSY.Generator,
    W <: AbstractSecurityConstrainedUnitCommitment,
    X <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )
    associated_outages = unique([outage for (_, outage) in generator_outages_pairs])

    ptdf = get_PTDF_matrix(network_model)
    bus_numbers = PNM.get_bus_axis(ptdf)

    expression = lazy_container_addition!(
        container,
        T(),
        V,
        string.(IS.get_uuid.(associated_outages)),
        bus_numbers,
        time_steps,
    )

    network_reduction = get_network_reduction(network_model)

    for (device, outage) in generator_outages_pairs
        if !(outage in associated_outages)
            continue
        end
        outage_id = string(IS.get_uuid(outage))
        name = PSY.get_name(device)
        variable = get_variable(container, U(), typeof(device))
        mult = _get_variable_multiplier(U(), typeof(device), W())
        bus_number = PNM.get_mapped_bus_number(network_reduction, PSY.get_bus(device))
        for t in time_steps
            _add_to_jump_expression!(
                expression[outage_id, bus_number, t],
                variable[name, t],
                mult,
            )
        end
    end

    return
end

function add_to_expression!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyBranchFlow,
    U <: FlowActivePowerVariable,
    V <: PSY.Generator,
    W <: AbstractSecurityConstrainedUnitCommitment,
    X <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )
    associated_outages = unique([outage for (_, outage) in generator_outages_pairs])

    network_reduction_data = get_network_reduction(network_model)
    branches_names = get_branch_name_variable_axis(network_reduction_data)

    expression_container = lazy_container_addition!(
        container,
        T(),
        V,
        string.(IS.get_uuid.(associated_outages)),
        branches_names,
        time_steps,
    )
    reduced_branch_tracker = get_reduced_branch_tracker(network_model)
    reduced_branch_expression_tracker = get_expression_dict(reduced_branch_tracker)
    ac_transmission_types = PNM.get_ac_transmission_types(network_reduction_data)
    all_branch_maps_by_type = network_reduction_data.all_branch_maps_by_type

    for ac_type in ac_transmission_types
        !(ac_type in network_model.modeled_branch_types) && continue
        flow_variables = get_variable(
            container,
            U(),
            ac_type,
        )
        for t in time_steps
            for map_name in NETWORK_REDUCTION_MAPS
                map = all_branch_maps_by_type[map_name]
                !haskey(map, ac_type) && continue
                for reduction_entry in values(map[ac_type])
                    expression_build_stage = 1
                    has_entry, entry_name = _search_for_reduced_branch_expression(
                        reduced_branch_tracker,
                        reduction_entry,
                        V,
                        "",
                        T,
                        expression_build_stage,
                        t,
                    )
                    if has_entry
                        equivalent_branch_expression =
                            reduced_branch_expression_tracker[(V, "")][(T, 1)][entry_name][t]
                    else
                        branch_name = first(_get_branch_names(reduction_entry))
                        variable = flow_variables[branch_name, t]
                        equivalent_branch_expression =
                            JuMP.@expression(get_jump_model(container), variable * 1.0)

                        _add_expression_to_tracker!(
                            reduced_branch_tracker,
                            equivalent_branch_expression,
                            reduction_entry,
                            V,
                            "",
                            T,
                            expression_build_stage,
                            t,
                        )
                    end
                    for outage in associated_outages
                        outage_id = string(IS.get_uuid(outage))
                        _add_expression_to_container!(
                            expression_container,
                            equivalent_branch_expression,
                            outage_id,
                            reduction_entry,
                            V,
                            t,
                        )
                    end
                end
            end
        end
    end
end

function add_to_expression!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyBranchFlow,
    U <: PostContingencyNodalActivePowerDeployment,
    V <: PSY.Generator,
    W <: AbstractSecurityConstrainedUnitCommitment,
    X <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )
    associated_outages = unique([outage for (_, outage) in generator_outages_pairs])

    network_reduction_data = get_network_reduction(network_model)
    branches_names = get_branch_name_variable_axis(network_reduction_data)

    expression_container = lazy_container_addition!(
        container,
        T(),
        V,
        string.(IS.get_uuid.(associated_outages)),
        branches_names,
        time_steps,
    )

    reduced_branch_tracker = get_reduced_branch_tracker(network_model)
    reduced_branch_expression_tracker = get_expression_dict(reduced_branch_tracker)
    ac_transmission_types = PNM.get_ac_transmission_types(network_reduction_data)
    all_branch_maps_by_type = network_reduction_data.all_branch_maps_by_type

    nodal_power_deployment_expressions = get_expression(container, U(), V)

    jump_model = get_jump_model(container)
    ptdf = get_PTDF_matrix(network_model)

    for ac_type in ac_transmission_types
        !(ac_type in network_model.modeled_branch_types) && continue
        for map_name in NETWORK_REDUCTION_MAPS
            map = all_branch_maps_by_type[map_name]
            !haskey(map, ac_type) && continue
            for (arc_tuple, reduction_entry) in map[ac_type]
                ptdf_col = ptdf[arc_tuple, :]
                for outage in associated_outages
                    outage_id = string(IS.get_uuid(outage))
                    expression_build_stage = 2
                    has_entry, entry_name = _search_for_reduced_branch_expression(
                        reduced_branch_tracker,
                        reduction_entry,
                        V,
                        "",
                        T,
                        expression_build_stage,
                        time_steps[1],
                    )
                    if has_entry
                        equivalent_branch_expressions =
                            [
                                reduced_branch_expression_tracker[(V, "")][(
                                    T,
                                    1,
                                )][entry_name][t] for t in time_steps
                            ]
                    else
                        branch_name = first(_get_branch_names(reduction_entry))
                        equivalent_branch_expressions = _make_flow_expressions!(
                            jump_model,
                            branch_name * string(outage_id),
                            time_steps,
                            ptdf_col,
                            nodal_power_deployment_expressions[outage_id, :, :].data,
                        )
                        for (ix, t) in enumerate(time_steps)
                            equivalent_branch_expression = equivalent_branch_expressions[ix]
                            _add_expression_to_tracker!(
                                reduced_branch_tracker,
                                equivalent_branch_expression,
                                reduction_entry,
                                V,
                                "",
                                T,
                                expression_build_stage,
                                t,
                            )
                        end
                    end
                    for (ix, t) in enumerate(time_steps)
                        equivalent_branch_expression = equivalent_branch_expressions[ix]
                        _add_expression_to_container!(
                            expression_container,
                            equivalent_branch_expression,
                            outage_id,
                            reduction_entry,
                            V,
                            t,
                        )
                    end
                end
            end
        end
    end
end

"""
Add branch post-contingency rate limit constraints for ACTransmission after a G-k outage
"""
function add_constraints!(
    container::OptimizationContainer,
    sys::PSY.System,
    cons_type::Type{T},
    ::Type{U},
    branches::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    device_model::DeviceModel{R, F},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {
    T <: PostContingencyEmergencyRateLimitConstraint,
    U <: PostContingencyBranchFlow,
    V <: PSY.ACTransmission,
    R <: PSY.Generator,
    F <: AbstractSecurityConstrainedUnitCommitment,
}
    reduced_branch_tracker = get_reduced_branch_tracker(network_model)
    network_reduction_data = get_network_reduction(network_model)
    ac_transmission_types = PNM.get_ac_transmission_types(network_reduction_data)
    all_branch_maps_by_type = network_reduction_data.all_branch_maps_by_type

    device_names = get_branch_name_constraint_axis(
        network_reduction_data,
        all_branch_maps_by_type,
        RateLimitConstraint,
        reduced_branch_tracker,
    )
    time_steps = get_time_steps(container)

    generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )
    associated_outages = unique([outage for (_, outage) in generator_outages_pairs])

    con_lb =
        add_constraints_container!(
            container,
            T(),
            R,
            string.(IS.get_uuid.(associated_outages)),
            device_names,
            time_steps;
            meta = "lb",
        )

    con_ub =
        add_constraints_container!(
            container,
            T(),
            R,
            string.(IS.get_uuid.(associated_outages)),
            device_names,
            time_steps;
            meta = "ub",
        )
    expressions = get_expression(container, U(), R, "")
    for ac_type in ac_transmission_types
        !(ac_type in network_model.modeled_branch_types) && continue
        for map in NETWORK_REDUCTION_MAPS
            network_reduction_map = all_branch_maps_by_type[map]
            !haskey(network_reduction_map, ac_type) && continue
            #!haskey(network_model.modeled_branch_types, ac_type) && continue
            for (_, reduction_entry) in network_reduction_map[ac_type]
                limits =
                    get_min_max_limits(reduction_entry, RateLimitConstraint, StaticBranch)    # TODO - Add method to use PostContingencyEmergencyRateLimitConstraint to get rating b 
                names = _get_branch_names(reduction_entry)
                for ci_name in names
                    if ci_name in device_names
                        for outage in associated_outages
                            outage_id = string(IS.get_uuid(outage))
                            for t in time_steps
                                con_ub[outage_id, ci_name, t] =
                                    JuMP.@constraint(get_jump_model(container),
                                        expressions[outage_id, ci_name, t] <=
                                        limits.max)
                                con_lb[outage_id, ci_name, t] =
                                    JuMP.@constraint(get_jump_model(container),
                                        expressions[outage_id, ci_name, t] >=
                                        limits.min)
                            end
                        end
                    end
                end
            end
        end
    end
    return
end

"""
This function adds the post-contingency ramping limits
"""
function add_constraints!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    model::Union{DeviceModel{R, F}, ServiceModel{R, F}},
    ::NetworkModel{N};
    service::S = "",
) where {
    T <: PostContingencyRampConstraint,
    U <: AbstractContingencyVariableType,
    V <: PSY.Generator,
    R <: Union{PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}, PSY.Generator},
    F <: Union{AbstractSecurityConstrainedUnitCommitment,
        AbstractSecurityConstrainedReservesFormulation},
    N <: AbstractPTDFModel,
    S <: Union{PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}, String},
}
    add_linear_ramp_constraints!(
        container,
        sys,
        T,
        U,
        devices,
        model,
        N;
        service = service,
    )
    return
end

@doc raw"""
Constructs allowed rate-of-change constraints for G-1 formulations from change_variables, and rate data.



``` change_variable[name, t] <= rate_data[1][ix].up ```

``` change_variable[name, t-1] >= rate_data[1][ix].down ```

# LaTeX

`` r^{down} \leq \Delta x_t  \leq r^{up}, \forall t \geq  ``

"""
function add_linear_ramp_constraints!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    model::Union{DeviceModel{R, F}, ServiceModel{R, F}},
    ::Type{<:AbstractPTDFModel};
    service::S = "",
) where {
    T <: PostContingencyConstraintType,
    U <: AbstractContingencyVariableType,
    V <: PSY.Generator,
    R <: Union{PSY.Generator, PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}},
    F <: Union{AbstractSecurityConstrainedUnitCommitment,
        AbstractSecurityConstrainedReservesFormulation},
    S <: Union{PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}, String},
}
    time_steps = get_time_steps(container)

    if isa(service, String)
        service_name = ""
        generator_outages_pairs = PSY.get_component_supplemental_attribute_pairs(
            PSY.Generator,
            PSY.UnplannedOutage,
            sys,
        )
        associated_outages = unique([outage for (_, outage) in generator_outages_pairs])
    else
        service_name = PSY.get_name(service)
        associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)
    end

    ramp_devices = _get_ramp_constraint_devices(container, devices)
    minutes_per_period = _get_minutes_per_period(container)

    device_name_set = PSY.get_name.(ramp_devices)
    set_outages_name = [string(IS.get_uuid(r)) for r in associated_outages]
    if device_name_set == []
        @debug "No Contributing devices to service $service with ramping constraints found in the system."
        return
    end

    constraint =
        add_constraints_container!(
            container,
            T(),
            R,
            set_outages_name,
            device_name_set,
            time_steps;
            meta = "$service_name",
        )

    variable = get_variable(
        container,
        U(),
        R,
        service_name,
    )

    for device in devices
        name = PSY.get_name(device)
        # This is to filter out devices that dont need a ramping constraint
        name ∉ device_name_set && continue
        ramp_limits = PSY.get_ramp_limits(device)

        @debug "add post-contingency ramping constraint for device $name"

        for outage in associated_outages
            name_outage = string(IS.get_uuid(outage))
            associated_devices =
                PSY.get_associated_components(
                    sys,
                    outage;
                    component_type = PSY.Generator,
                )

            if device in associated_devices
                continue
            end

            for t in time_steps
                _add_post_contingency_ramp_constraints!(
                    container,
                    U,
                    variable,
                    constraint,
                    name_outage,
                    name,
                    t,
                    ramp_limits,
                    minutes_per_period,
                    S,
                )
            end
        end
    end

    return
end

function _add_post_contingency_ramp_constraints!(
    container::OptimizationContainer,
    ::Type{PostContingencyActivePowerChangeVariable},
    variable,
    constraint,
    name_outage::String,
    name::String,
    t::Int64,
    ramp_limits,
    minutes_per_period::Int64,
    R::Type{<:String},
)
    constraint[name_outage, name, t] = JuMP.@constraint(
        get_jump_model(container),
        variable[name_outage, name, t] <=
        ramp_limits.up * minutes_per_period
    )

    return
end

function _add_post_contingency_ramp_constraints!(
    container::OptimizationContainer,
    ::Type{PostContingencyActivePowerReserveDeploymentVariable},
    variable,
    con_up,
    name_outage::String,
    name::String,
    t::Int64,
    ramp_limits,
    minutes_per_period::Int64,
    R::Type{<:PSY.Reserve{PSY.ReserveUp}},
)
    con_up[name_outage, name, t] = JuMP.@constraint(
        get_jump_model(container),
        variable[name_outage, name, t] <=
        ramp_limits.up * minutes_per_period
    )

    return
end

function _add_post_contingency_ramp_constraints!(
    container::OptimizationContainer,
    ::Type{PostContingencyActivePowerReserveDeploymentVariable},
    variable,
    con_down,
    name_outage::String,
    name::String,
    t::Int64,
    ramp_limits,
    minutes_per_period::Int64,
    R::Type{<:PSY.Reserve{PSY.ReserveDown}},
)
    con_down[name_outage, name, t] = JuMP.@constraint(
        get_jump_model(container),
        variable[name_outage, name, t] <=
        ramp_limits.down * minutes_per_period
    )
    return
end

#G-1 WITH RESERVES AND DELIVERABILITY CONSTRAINTS

function add_variables!(
    container::OptimizationContainer,
    sys::PSY.System,
    variable_type::Type{T},
    service::R,
    contributing_devices::Vector{V},
    formulation::AbstractSecurityConstrainedReservesFormulation,
) where {
    T <: AbstractContingencyVariableType,
    R <: PSY.AbstractReserve,
    V <: PSY.StaticInjection,
}
    @assert !isempty(contributing_devices)
    time_steps = get_time_steps(container)
    binary = get_variable_binary(variable_type(), R, formulation)

    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)

    variable = lazy_container_addition!(
        container,
        variable_type(),
        R,
        [string(IS.get_uuid(outage)) for outage in associated_outages],
        [PSY.get_name(d) for d in contributing_devices],
        time_steps;
        meta = get_name(service),
    )

    for outage in associated_outages
        outage_name = string(IS.get_uuid(outage))
        associated_devices =
            PSY.get_associated_components(sys, outage; component_type = PSY.Generator)

        for device in contributing_devices
            name = PSY.get_name(device)
            device_is_in_reserve_devices = device in associated_devices

            for t in time_steps
                variable[outage_name, name, t] = JuMP.@variable(
                    get_jump_model(container),
                    base_name = "$(T)_$(R)_$(PSY.get_name(service))_{$(outage_name), $(name), $(t)}",
                    binary = binary
                )
                if device_is_in_reserve_devices
                    #The device that suffered the outage cannot contribute with reserves deployment for its own contingency.
                    JuMP.set_upper_bound(variable[outage_name, name, t], 0.0)
                    JuMP.set_lower_bound(variable[outage_name, name, t], 0.0)
                    JuMP.set_start_value(variable[outage_name, name, t], 0.0)
                    continue
                end

                ub = get_variable_upper_bound(variable_type(), service, device, formulation)
                ub !== nothing && JuMP.set_upper_bound(variable[outage_name, name, t], ub)

                lb = get_variable_lower_bound(variable_type(), service, device, formulation)
                lb !== nothing && !binary &&
                    JuMP.set_lower_bound(variable[outage_name, name, t], lb)

                init = get_variable_warm_start_value(variable_type(), device, formulation)
                init !== nothing &&
                    JuMP.set_start_value(variable[outage_name, name, t], init)
            end
        end
    end
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, F},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.AbstractReserve,
    F <: AbstractSecurityConstrainedReservesFormulation}
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

    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)
    if isempty(associated_outages)
        @warn "No associated outage supplemental attributes found for service: $SR('$name'). Skipping contingency variable addition for service formulation $F."
        return
    end

    add_variables!(
        container,
        sys,
        PostContingencyActivePowerReserveDeploymentVariable,
        service,
        contributing_devices,
        F(),
    )

    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, F},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {SR <: PSY.AbstractReserve,
    F <: AbstractSecurityConstrainedReservesFormulation}
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

    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)
    if isempty(associated_outages)
        @warn "No associated outage supplemental attributes found for service: $SR('$name'). Skipping contingency expresions/constraints addition for service formulation $F."
        return
    end

    # Consider if the expressions are needed or just create the constraint
    add_to_expression!(
        container,
        sys,
        PostContingencyActivePowerBalance,
        PostContingencyActivePowerReserveDeploymentVariable,
        contributing_devices,
        service,
        model,
        network_model,
    )

    attribute_device_map = PSY.get_component_supplemental_attribute_pairs(
        PSY.Generator,
        PSY.UnplannedOutage,
        sys,
    )

    add_to_expression!(
        container,
        PostContingencyActivePowerBalance,
        ActivePowerVariable,
        attribute_device_map,
        service,
        model,
        network_model,
    )

    add_to_expression!(
        container,
        sys,
        PostContingencyNodalActivePowerDeployment,
        PostContingencyActivePowerReserveDeploymentVariable,
        contributing_devices,
        service,
        model,
        network_model,
    )

    add_to_expression!(
        container,
        PostContingencyNodalActivePowerDeployment,
        ActivePowerVariable,
        attribute_device_map,
        service,
        model,
        network_model,
    )

    # #ADD EXPRESSION TO CALCULATE POST CONTINGENCY FLOW FOR EACH Branch
    add_to_expression!(
        container,
        sys,
        PostContingencyBranchFlow,
        FlowActivePowerVariable,
        contributing_devices,
        service,
        model,
        network_model,
    )

    add_to_expression!(
        container,
        sys,
        PostContingencyBranchFlow,
        PostContingencyNodalActivePowerDeployment,
        contributing_devices,
        service,
        model,
        network_model,
    )

    add_constraints!(
        container,
        sys,
        PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
        ActivePowerReserveVariable,
        PostContingencyActivePowerReserveDeploymentVariable,
        contributing_devices,
        service,
        model,
        network_model,
    )

    add_constraints!(
        container,
        PostContingencyGenerationBalanceConstraint,
        PostContingencyActivePowerBalance,
        contributing_devices,
        service,
        model,
        network_model,
    )

    add_constraints!(
        container,
        PostContingencyEmergencyRateLimitConstraint,
        PostContingencyBranchFlow,
        PSY.get_available_components(PSY.ACTransmission, sys),
        service,
        model,
        network_model,
    )

    #ADD RAMPING CONSTRAINTS
    add_constraints!(
        container,
        sys,
        PostContingencyRampConstraint,
        PostContingencyActivePowerReserveDeploymentVariable,
        contributing_devices,
        model,
        network_model;
        service = service,
    )

    return
end

"""
Default implementation to add active power variables variables to PostContingencySystemBalanceExpressions for G-1 formulation with reserves
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    attribute_device_map::Vector{
        NamedTuple{(:component, :supplemental_attribute), Tuple{V, PSY.UnplannedOutage}},
    },
    service::R,
    reserves_model::ServiceModel{R, F},
    network_model::NetworkModel{N},
) where {
    T <: PostContingencyActivePowerBalance,
    U <: VariableType,
    V <: PSY.Generator,
    R <: PSY.AbstractReserve,
    F <: AbstractSecurityConstrainedReservesFormulation,
    N <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)

    expression = lazy_container_addition!(
        container,
        T(),
        R,
        string.(IS.get_uuid.(associated_outages)),
        time_steps;
        meta = service_name,
    )

    for (d, outage) in attribute_device_map
        if !(outage in associated_outages)
            continue
        end
        name_outage = string(IS.get_uuid(outage))
        name = PSY.get_name(d)
        variable = get_variable(container, U(), typeof(d))
        mult = get_variable_multiplier(U(), typeof(d), F())

        for t in time_steps
            _add_to_jump_expression!(
                expression[name_outage, t],
                variable[name, t],
                mult,
            )
        end
    end
    return
end

"""
Default implementation to add Reserve deployment variables to PostContingencySystemBalanceExpressions for G-1 formulation with reserves
"""
function add_to_expression!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    contributing_devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    service::R,
    reserves_model::ServiceModel{R, F},
    network_model::NetworkModel{N},
) where {
    T <: PostContingencyActivePowerBalance,
    U <: AbstractContingencyVariableType,
    V <: PSY.Generator,
    R <: PSY.AbstractReserve,
    F <: AbstractSecurityConstrainedReservesFormulation,
    N <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)

    expression = lazy_container_addition!(
        container,
        T(),
        R,
        string.(IS.get_uuid.(associated_outages)),
        time_steps;
        meta = service_name,
    )

    reserve_deployment_variable = get_variable(container, U(), R, service_name)
    mult = get_variable_multiplier(U(), R, F())

    for outage in associated_outages
        associated_devices =
            PSY.get_associated_components(sys, outage; component_type = PSY.Generator) #Use PSY.Generator To make sure it considers ALL generators associated with the outage instance

        name_outage = string(IS.get_uuid(outage))

        for device in contributing_devices
            name = PSY.get_name(device)

            if device in associated_devices #The contributting device cannot contribute to the reserves deployment if it has the outage
                continue
            end

            for t in time_steps
                _add_to_jump_expression!(
                    expression[name_outage, t],
                    reserve_deployment_variable[name_outage, name, t],
                    mult,
                )
            end
        end
    end

    return
end

function add_to_expression!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    contributing_devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    service::R,
    reserves_model::ServiceModel{R, F},
    network_model::NetworkModel{N},
) where {
    T <: PostContingencyNodalActivePowerDeployment,
    U <: AbstractContingencyVariableType,
    V <: PSY.Generator,
    R <: PSY.AbstractReserve,
    F <: AbstractSecurityConstrainedReservesFormulation,
    N <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)

    ptdf = get_PTDF_matrix(network_model)
    bus_numbers = PNM.get_bus_axis(ptdf)

    expression = lazy_container_addition!(
        container,
        T(),
        R,
        string.(IS.get_uuid.(associated_outages)),
        bus_numbers,
        time_steps;
        meta = service_name,
    )

    reserve_deployment_variable = get_variable(container, U(), R, service_name)
    mult = get_variable_multiplier(U(), R, F())

    network_reduction = get_network_reduction(network_model)

    for outage in associated_outages
        associated_devices =
            PSY.get_associated_components(sys, outage; component_type = PSY.Generator) #Use PSY.Generator To make sure it considers ALL generators associated with the outage instance
        outage_id = string(IS.get_uuid(outage))

        for device in contributing_devices
            if device in associated_devices
                continue
            end

            name = PSY.get_name(device)
            bus_number = PNM.get_mapped_bus_number(network_reduction, PSY.get_bus(device))

            for t in time_steps
                _add_to_jump_expression!(
                    expression[outage_id, bus_number, t],
                    reserve_deployment_variable[outage_id, name, t],
                    mult,
                )
            end
        end
    end

    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    attribute_device_map::Vector{
        NamedTuple{(:component, :supplemental_attribute), Tuple{V, PSY.UnplannedOutage}},
    },
    service::R,
    reserves_model::ServiceModel{R, F},
    network_model::NetworkModel{N},
) where {
    T <: PostContingencyNodalActivePowerDeployment,
    U <: VariableType,
    V <: PSY.Generator,
    R <: PSY.AbstractReserve,
    F <: AbstractSecurityConstrainedReservesFormulation,
    N <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)

    ptdf = get_PTDF_matrix(network_model)
    bus_numbers = PNM.get_bus_axis(ptdf)

    expression = lazy_container_addition!(
        container,
        T(),
        R,
        string.(IS.get_uuid.(associated_outages)),
        bus_numbers,
        time_steps;
        meta = service_name,
    )

    network_reduction = get_network_reduction(network_model)

    for (device, outage) in attribute_device_map
        if !(outage in associated_outages)
            continue
        end
        name_outage = string(IS.get_uuid(outage))
        name = PSY.get_name(device)
        variable = get_variable(container, U(), typeof(device))
        mult = get_variable_multiplier(U(), typeof(device), F())
        bus_number = PNM.get_mapped_bus_number(network_reduction, PSY.get_bus(device))
        for t in time_steps
            _add_to_jump_expression!(
                expression[name_outage, bus_number, t],
                variable[name, t],
                mult,
            )
        end
    end

    return
end

function add_to_expression!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    contributing_devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    service::R,
    reserves_model::ServiceModel{R, F},
    network_model::NetworkModel{N},
) where {
    T <: PostContingencyBranchFlow,
    U <: PostContingencyNodalActivePowerDeployment,
    V <: PSY.Generator,
    R <: PSY.AbstractReserve,
    F <: AbstractSecurityConstrainedReservesFormulation,
    N <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)

    service_name = PSY.get_name(service)
    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)

    network_reduction_data = get_network_reduction(network_model)
    branches_names = get_branch_name_variable_axis(network_reduction_data)

    expression_container = lazy_container_addition!(
        container,
        T(),
        R,
        string.(IS.get_uuid.(associated_outages)),
        branches_names,
        time_steps;
        meta = service_name,
    )
    reduced_branch_tracker = get_reduced_branch_tracker(network_model)
    reduced_branch_expression_tracker = get_expression_dict(reduced_branch_tracker)
    ac_transmission_types = PNM.get_ac_transmission_types(network_reduction_data)
    all_branch_maps_by_type = network_reduction_data.all_branch_maps_by_type

    nodal_power_deployment_expressions = get_expression(container, U(), R, service_name)

    jump_model = get_jump_model(container)
    ptdf = get_PTDF_matrix(network_model)

    for ac_type in ac_transmission_types
        !(ac_type in network_model.modeled_branch_types) && continue
        for map_name in NETWORK_REDUCTION_MAPS
            map = all_branch_maps_by_type[map_name]
            !haskey(map, ac_type) && continue
            for (arc_tuple, reduction_entry) in map[ac_type]
                ptdf_col = ptdf[arc_tuple, :]
                for outage in associated_outages
                    outage_id = string(IS.get_uuid(outage))
                    expression_build_stage = 2
                    has_entry, entry_name = _search_for_reduced_branch_expression(
                        reduced_branch_tracker,
                        reduction_entry,
                        R,
                        service_name,
                        T,
                        expression_build_stage,
                        time_steps[1],
                    )
                    if has_entry
                        equivalent_branch_expressions =
                            [
                                reduced_branch_expression_tracker[(R, service_name)][(
                                    T,
                                    1,
                                )][entry_name][t] for t in time_steps
                            ]
                    else
                        branch_name = first(_get_branch_names(reduction_entry))
                        equivalent_branch_expressions = _make_flow_expressions!(
                            jump_model,
                            branch_name * string(outage_id),
                            time_steps,
                            ptdf_col,
                            nodal_power_deployment_expressions[outage_id, :, :].data,
                        )
                        for (ix, t) in enumerate(time_steps)
                            equivalent_branch_expression = equivalent_branch_expressions[ix]
                            _add_expression_to_tracker!(
                                reduced_branch_tracker,
                                equivalent_branch_expression,
                                reduction_entry,
                                R,
                                service_name,
                                T,
                                expression_build_stage,
                                t,
                            )
                        end
                    end
                    for (ix, t) in enumerate(time_steps)
                        equivalent_branch_expression = equivalent_branch_expressions[ix]
                        _add_expression_to_container!(
                            expression_container,
                            equivalent_branch_expression,
                            outage_id,
                            reduction_entry,
                            R,
                            t,
                        )
                    end
                end
            end
        end
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    ::Type{U},
    contributing_devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    service::R,
    reserves_model::ServiceModel{R, F},
    network_model::NetworkModel{N},
) where {
    T <: PostContingencyBranchFlow,
    U <: FlowActivePowerVariable,
    V <: PSY.Generator,
    R <: PSY.AbstractReserve,
    F <: AbstractSecurityConstrainedReservesFormulation,
    N <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)

    network_reduction_data = get_network_reduction(network_model)
    branches_names = get_branch_name_variable_axis(network_reduction_data)

    expression_container = lazy_container_addition!(
        container,
        T(),
        R,
        string.(IS.get_uuid.(associated_outages)),
        branches_names,
        time_steps;
        meta = service_name,
    )
    reduced_branch_tracker = get_reduced_branch_tracker(network_model)
    reduced_branch_expression_tracker = get_expression_dict(reduced_branch_tracker)
    ac_transmission_types = PNM.get_ac_transmission_types(network_reduction_data)
    all_branch_maps_by_type = network_reduction_data.all_branch_maps_by_type

    for ac_type in ac_transmission_types
        !(ac_type in network_model.modeled_branch_types) && continue
        flow_variables = get_variable(
            container,
            U(),
            ac_type,
        )
        for t in time_steps
            for map_name in NETWORK_REDUCTION_MAPS
                map = all_branch_maps_by_type[map_name]
                !haskey(map, ac_type) && continue
                for reduction_entry in values(map[ac_type])
                    expression_build_stage = 1
                    has_entry, entry_name = _search_for_reduced_branch_expression(
                        reduced_branch_tracker,
                        reduction_entry,
                        R,
                        service_name,
                        T,
                        expression_build_stage,
                        t,
                    )
                    if has_entry
                        equivalent_branch_expression =
                            reduced_branch_expression_tracker[(R, service_name)][(T, 1)][entry_name][t]
                    else
                        branch_name = first(_get_branch_names(reduction_entry))
                        variable = flow_variables[branch_name, t]
                        equivalent_branch_expression =
                            JuMP.@expression(get_jump_model(container), variable * 1.0)

                        _add_expression_to_tracker!(
                            reduced_branch_tracker,
                            equivalent_branch_expression,
                            reduction_entry,
                            R,
                            service_name,
                            T,
                            expression_build_stage,
                            t,
                        )
                    end
                    for outage in associated_outages
                        outage_id = string(IS.get_uuid(outage))
                        _add_expression_to_container!(
                            expression_container,
                            equivalent_branch_expression,
                            outage_id,
                            reduction_entry,
                            R,
                            t,
                        )
                    end
                end
            end
        end
    end
    return
end

function _add_expression_to_container!(
    expression_container::JuMPAffineExpression3DArrayStringStringInt,
    expression::JuMP.AffExpr,
    outage_id::String,
    entry::U,
    type::Type{T},
    t,
) where {T <: PSY.Component, U <: PSY.ACTransmission}
    name = PSY.get_name(entry)
    JuMP.add_to_expression!(expression_container[outage_id, name, t], expression)
    #expression_container[outage_id, name, t] = expression
end

function _add_expression_to_container!(
    expression_container::JuMPAffineExpression3DArrayStringStringInt,
    expression::JuMP.AffExpr,
    outage_id::String,
    double_circuit::Set{U},
    type::Type{T},
    t,
) where {T <: PSY.Component, U <: PSY.ACTransmission}
    for circuit in double_circuit
        name = PSY.get_name(circuit) * "_double_circuit"
        JuMP.add_to_expression!(expression_container[outage_id, name, t], expression)
        #expression_container[outage_id, name, t] = expression
    end
end

function _add_expression_to_container!(
    expression_container::JuMPAffineExpression3DArrayStringStringInt,
    expression::JuMP.AffExpr,
    outage_id::String,
    series_chain::Vector{Any},
    type::Type{T},
    t,
) where {T <: PSY.Component}
    for segment in series_chain
        _add_expression_to_container!(#TODO REVIEW IF THIS OVERWRITING
            expression_container,
            expression,
            outage_id,
            segment,
            type,
            t,
        )
    end
end

"""
Add post-contingency Generation Balance Constraints for Generators for G-k with reserves formulation (SecurityConstrainedReservesFormulation)
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    contributing_devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    service::R,
    model::ServiceModel{R, F},
    ::NetworkModel{<:AbstractPTDFModel},
) where {
    T <: PostContingencyGenerationBalanceConstraint,
    U <: PostContingencyActivePowerBalance,
    V <: PSY.Generator,
    R <: PSY.AbstractReserve,
    F <: AbstractSecurityConstrainedReservesFormulation,
}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)

    expressions = get_expression(container, U(), R, service_name)

    constraint = add_constraints_container!(
        container,
        T(),
        R,
        [string(IS.get_uuid(o)) for o in associated_outages],
        time_steps;
        meta = service_name,
    )

    j_model = get_jump_model(container)

    for t in time_steps, outage in associated_outages
        name_outage = string(IS.get_uuid(outage))
        constraint[name_outage, t] =
            JuMP.@constraint(j_model, expressions[name_outage, t] == 0)
    end
    return
end

"""
Add branch post-contingency rate limit constraints for ACTransmission after a G-k outage for G-k with reserves formulation (SecurityConstrainedReservesFormulation)
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{T},
    ::Type{U},
    branches::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    service::R,
    device_model::ServiceModel{R, F},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {
    T <: PostContingencyEmergencyRateLimitConstraint,
    U <: PostContingencyBranchFlow,
    V <: PSY.ACTransmission,
    R <: PSY.AbstractReserve,
    F <: AbstractSecurityConstrainedReservesFormulation,
}
    reduced_branch_tracker = get_reduced_branch_tracker(network_model)
    network_reduction_data = get_network_reduction(network_model)
    ac_transmission_types = PNM.get_ac_transmission_types(network_reduction_data)
    all_branch_maps_by_type = network_reduction_data.all_branch_maps_by_type

    device_names = get_branch_name_constraint_axis(
        network_reduction_data,
        all_branch_maps_by_type,
        RateLimitConstraint,
        reduced_branch_tracker,
    )
    time_steps = get_time_steps(container)

    service_name = PSY.get_name(service)
    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)

    con_lb =
        add_constraints_container!(
            container,
            T(),
            R,
            string.(IS.get_uuid.(associated_outages)),
            device_names,
            time_steps;
            meta = "$service_name -lb",
        )

    con_ub =
        add_constraints_container!(
            container,
            T(),
            R,
            string.(IS.get_uuid.(associated_outages)),
            device_names,
            time_steps;
            meta = "$service_name -ub",
        )
    expressions = get_expression(container, U(), R, service_name)
    for ac_type in ac_transmission_types
        !(ac_type in network_model.modeled_branch_types) && continue
        for map in NETWORK_REDUCTION_MAPS
            network_reduction_map = all_branch_maps_by_type[map]
            !haskey(network_reduction_map, ac_type) && continue
            for (_, reduction_entry) in network_reduction_map[ac_type]
                limits =
                    get_min_max_limits(reduction_entry, RateLimitConstraint, StaticBranch)    # TODO - Add method to use PostContingencyEmergencyRateLimitConstraint to get rating b 
                names = _get_branch_names(reduction_entry)
                for ci_name in names
                    if ci_name in device_names
                        for outage in associated_outages
                            outage_id = string(IS.get_uuid(outage))
                            for t in time_steps
                                con_ub[outage_id, ci_name, t] =
                                    JuMP.@constraint(get_jump_model(container),
                                        expressions[outage_id, ci_name, t] <=
                                        limits.max)
                                con_lb[outage_id, ci_name, t] =
                                    JuMP.@constraint(get_jump_model(container),
                                        expressions[outage_id, ci_name, t] >=
                                        limits.min)
                            end
                        end
                    end
                end
            end
        end
    end
    return
end

function _add_expression_to_container!(
    expression_container::JuMPAffineExpression3DArrayStringStringInt,
    expression::JuMP.AffExpr,
    outage_id::String,
    entry::U,
    type::Type{T},
    t,
) where {T <: PSY.Component, U <: PSY.ACTransmission}
    name = PSY.get_name(entry)
    JuMP.add_to_expression!(expression_container[outage_id, name, t], expression)
    #expression_container[outage_id, name, t] = expression
end

function _add_expression_to_container!(
    expression_container::JuMPAffineExpression3DArrayStringStringInt,
    expression::JuMP.AffExpr,
    outage_id::String,
    double_circuit::Set{U},
    type::Type{T},
    t,
) where {T <: PSY.Component, U <: PSY.ACTransmission}
    for circuit in double_circuit
        name = PSY.get_name(circuit) * "_double_circuit"
        JuMP.add_to_expression!(expression_container[outage_id, name, t], expression)
    end
end

function _add_expression_to_container!(
    expression_container::JuMPAffineExpression3DArrayStringStringInt,
    expression::JuMP.AffExpr,
    outage_id::String,
    series_chain::Vector{Any},
    type::Type{T},
    t,
) where {T <: PSY.Component}
    for segment in series_chain
        _add_expression_to_container!(#todo review this
            expression_container,
            expression,
            outage_id,
            segment,
            type,
            t,
        )
    end
end

function add_constraints!(
    container::OptimizationContainer,
    sys::PSY.System,
    T::Type{<:PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint},
    X::Type{<:VariableType},
    U::Type{<:AbstractContingencyVariableType},
    contributing_devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    service::R,
    model::ServiceModel{R, F},
    ::NetworkModel{<:AbstractPTDFModel},
) where {
    V <: PSY.Generator,
    R <: PSY.AbstractReserve,
    F <: AbstractSecurityConstrainedReservesFormulation,
}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)

    constraint =
        add_constraints_container!(
            container,
            T(),
            R,
            [string(IS.get_uuid(r)) for r in associated_outages],
            [PSY.get_name(r) for r in contributing_devices],
            time_steps;
            meta = service_name,
        )

    variable = get_variable(
        container,
        X(),
        R,
        service_name,
    )

    variable_outage = get_variable(
        container,
        U(),
        R,
        service_name,
    )

    for outage in associated_outages
        associated_devices =
            PSY.get_associated_components(sys, outage; component_type = PSY.Generator) #Use PSY.Generator To make sure it considers ALL generators associated with the outage instance
        name_outage = string(IS.get_uuid(outage))

        for device in contributing_devices
            name = get_name(device)
            @debug "adding $T for device $name and outage $name_outage"

            if device in associated_devices
                continue
            end

            for t in time_steps
                constraint[name_outage, name, t] = JuMP.@constraint(
                    get_jump_model(container),
                    variable_outage[name_outage, name, t] <=
                    variable[name, t]
                )
            end
        end
    end

    return
end
