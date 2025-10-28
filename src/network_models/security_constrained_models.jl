# TODO - error if a the outage is associated with a reduced branch in N-1 formulation

"""
Default implementation to add branch Expressions for Post-Contingency Flows
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    branches::IS.FlattenIteratorWrapper{PSY.ACTransmission},
    associated_outages_pairs::Vector{
        @NamedTuple{component::V, supplemental_attribute::PSY.UnplannedOutage}
    },
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyBranchFlow,
    U <: FlowActivePowerVariable,
    V <: PSY.ACTransmission,
    W <: AbstractBranchFormulation,
    X <: AbstractSecurityConstrainedPTDFModel,
}
    time_steps = get_time_steps(container)
    expressions = lazy_container_addition!(
        container,
        T(),
        V,
        [PSY.get_name(branch_outage) for (branch_outage, _) in associated_outages_pairs],
        get_name.(branches),
        time_steps,
    )

    lodf = get_LODF_matrix(network_model)
    variable_branches_outages = get_variable(container, U(), V)

    for branch in branches
        variable_branches = get_variable(container, U(), typeof(branch))
        branch_name = get_name(branch)

        for (branch_outage, outage) in associated_outages_pairs
            if branch_outage == branch
                continue
            end

            branch_outage_name = get_name(branch_outage)

            index_lodf_branch = (branch.arc.from.number, branch.arc.to.number)
            index_lodf_outage = (branch_outage.arc.from.number, branch_outage.arc.to.number)
            for t in time_steps
                _add_to_jump_expression!(
                    expressions[branch_outage_name, branch_name, t],
                    variable_branches[branch_name, t],
                    1.0,
                )

                _add_to_jump_expression!(
                    expressions[branch_outage_name, branch_name, t],
                    variable_branches_outages[branch_outage_name, t],
                    lodf[index_lodf_branch, index_lodf_outage],
                )
            end
        end
    end

    return
end

"""
Add branch post-contingency rate limit constraints for ACBranch considering LODF and Security Constraints
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{T},
    branches::IS.FlattenIteratorWrapper{PSY.ACTransmission},
    associated_outages_pairs::Vector{
        @NamedTuple{component::V, supplemental_attribute::PSY.UnplannedOutage}
    },
    device_model::DeviceModel{V, U},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyEmergencyRateLimitConstraint,
    V <: PSY.ACTransmission,
    U <: AbstractBranchFormulation,
    X <: AbstractSecurityConstrainedPTDFModel,
}
    time_steps = get_time_steps(container)
    device_names = PSY.get_name.(branches)

    con_lb = add_constraints_container!(
        container,
        cons_type(),
        V,
        [get_name(branch_outage) for (branch_outage, _) in associated_outages_pairs],
        device_names,
        time_steps;
        meta = "lb",
    )

    con_ub = add_constraints_container!(
        container,
        cons_type(),
        V,
        [get_name(branch_outage) for (branch_outage, _) in associated_outages_pairs],
        device_names,
        time_steps;
        meta = "ub",
    )

    expressions = get_expression(container, PostContingencyBranchFlow(), V)

    param_keys = get_parameter_keys(container)

    for branch in branches
        branch_name = get_name(branch)

        param_key = ParameterKey(
            PostContingencyDynamicBranchRatingTimeSeriesParameter,
            typeof(branch),
        )

        for (branch_outage, outage) in associated_outages_pairs
            if branch == branch_outage
                continue
            end

            b_outage_name = get_name(branch_outage)

            limits = get_min_max_limits(
                branch,
                T,
                U,
            )

            for t in time_steps
                con_ub[b_outage_name, branch_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[b_outage_name, branch_name, t] <=
                        limits.max)
                con_lb[b_outage_name, branch_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[b_outage_name, branch_name, t] >=
                        limits.min)
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
    devices::Union{
        IS.FlattenIteratorWrapper{PSY.ACTransmission},
        Vector{PSY.ACTransmission},
    },
    model::DeviceModel{V, F},
    network_model::NetworkModel{N},
) where {
    T <: PostContingencyBranchFlow,
    U <: FlowActivePowerVariable,
    V <: PSY.ACTransmission,
    F <: AbstractSecurityConstrainedStaticBranch,
    N <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    associated_outages = PSY.get_associated_supplemental_attributes(
        sys,
        V;
        attribute_type = PSY.UnplannedOutage,
    )

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

    lodf = get_LODF_matrix(network_model)

    contingency_flow_variables = get_variable(
        container,
        U(),
        V,
    )
    for ac_type in ac_transmission_types
        !(has_container_key(container, U, ac_type)) && continue
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
                        ac_type,
                        "",
                        T,
                        expression_build_stage,
                        t,
                    )
                    if has_entry
                        equivalent_branch_expression =
                            reduced_branch_expression_tracker[(ac_type, "")][(T, 1)][entry_name][t]
                    else
                        branch = reduction_entry
                        if !(reduction_entry isa PSY.ACTransmission)
                            branch = first(reduction_entry)
                        end

                        branch_name = first(_get_branch_names(reduction_entry))
                        variable = flow_variables[branch_name, t]

                        index_lodf_branch = (branch.arc.from.number, branch.arc.to.number)
                        equivalent_branch_expressions = Dict{String, JuMP.AffExpr}()
                        for outage in associated_outages
                            associated_devices =
                                PSY.get_associated_components(
                                    sys,
                                    outage;
                                    component_type = V,
                                )

                            associated_device = first(associated_devices)
                            outage_id = string(IS.get_uuid(outage))

                            if length(associated_devices) != 1
                                @warn(
                                    "Outage $(outage_id) is associated with $(length(associated_devices)) devices of type $V. Expected only one associated device per outage for contingency analysis. It is being component $(PSY.get_name(associated_device))."
                                )
                            end

                            index_lodf_outage = (
                                associated_device.arc.from.number,
                                associated_device.arc.to.number,
                            )

                            contingency_variable = contingency_flow_variables[
                                PSY.get_name(associated_device),
                                t,
                            ]
                            equivalent_branch_expressions[outage_id] =
                                JuMP.@expression(
                                    get_jump_model(container),
                                    variable * 1.0 +
                                    lodf[index_lodf_branch, index_lodf_outage] *
                                    contingency_variable
                                )

                            equivalent_branch_expression =
                                equivalent_branch_expressions[outage_id]

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
                    for outage in associated_outages
                        outage_id = string(IS.get_uuid(outage))
                        equivalent_branch_expression =
                            equivalent_branch_expressions[outage_id]
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
    return
end

"""
Add branch post-contingency rate limit constraints for ACTransmission after a N-1 outage for security constrained branch formulations
"""
function add_constraints!(
    container::OptimizationContainer,
    sys::PSY.System,
    cons_type::Type{T},
    ::Type{U},
    branches::Union{
        IS.FlattenIteratorWrapper{PSY.ACTransmission},
        Vector{PSY.ACTransmission},
    },
    device_model::DeviceModel{V, F},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {
    T <: PostContingencyEmergencyRateLimitConstraint,
    U <: PostContingencyBranchFlow,
    V <: PSY.ACTransmission,
    F <: AbstractSecurityConstrainedStaticBranch,
}
    reduced_branch_tracker = get_reduced_branch_tracker(network_model)
    network_reduction_data = get_network_reduction(network_model)
    ac_transmission_types = PNM.get_ac_transmission_types(network_reduction_data)
    all_branch_maps_by_type = network_reduction_data.all_branch_maps_by_type
    modeled_branch_types = _get_modeled_branch_types(container, network_model)

    device_names = get_branch_name_constraint_axis(
        modeled_branch_types,
        network_reduction_data,
        all_branch_maps_by_type,
        T,
        reduced_branch_tracker,
    )
    time_steps = get_time_steps(container)

    #service_name = PSY.get_name(service)
    associated_outages = PSY.get_associated_supplemental_attributes(
        sys,
        V;
        attribute_type = PSY.UnplannedOutage,
    )

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

    for ac_type in ac_transmission_types
        !(ac_type in modeled_branch_types) && continue
        for map in NETWORK_REDUCTION_MAPS
            network_reduction_map = all_branch_maps_by_type[map]
            !haskey(network_reduction_map, ac_type) && continue
            for (_, reduction_entry) in network_reduction_map[ac_type]
                limits =
                    get_min_max_limits(reduction_entry, T, StaticBranch)
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

# For DC Power only
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, F},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: PSY.ACTransmission, F <: AbstractSecurityConstrainedStaticBranch}
    devices = get_available_components(model, sys)
    if get_use_slacks(model)
        add_variables!(
            container,
            FlowActivePowerSlackUpperBound,
            network_model,
            devices,
            F(),
        )
        add_variables!(
            container,
            FlowActivePowerSlackLowerBound,
            network_model,
            devices,
            F(),
        )
    end

    add_variables!(
        container,
        FlowActivePowerVariable,
        network_model,
        devices,
        F(),
    )

    if haskey(get_time_series_names(model), DynamicBranchRatingTimeSeriesParameter)
        add_parameters!(container, DynamicBranchRatingTimeSeriesParameter, devices, model)
    end

    # Deactivating this since it does not seem that the industry or we have data for this
    # if haskey(
    #     get_time_series_names(model),
    #     PostContingencyDynamicBranchRatingTimeSeriesParameter,
    # )
    #     add_parameters!(
    #         container,
    #         PostContingencyDynamicBranchRatingTimeSeriesParameter,
    #         devices,
    #         model,
    #     )
    # end

    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{V, F},
    network_model::NetworkModel{X},
) where {
    V <: PSY.ACTransmission,
    F <: AbstractSecurityConstrainedStaticBranch,
    X <: AbstractPTDFModel,
}
    devices = get_available_components(model, sys)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraints!(container, RateLimitConstraint, devices, model, network_model)

    associated_outages = PSY.get_associated_supplemental_attributes(
        sys,
        V;
        attribute_type = PSY.UnplannedOutage,
    )

    if isempty(associated_outages)
        @info "No associated outage supplemental attributes found associated with devices: $V. Skipping contingency variable addition for that device type."
        return
    end

    network_reduction = get_network_reduction(network_model)#TODO Check with Matt This
    branches_names = PNM.get_retained_branches_names(network_reduction)

    branches = get_available_components(
        #b -> PSY.get_name(b) in branches_names,
        PSY.ACTransmission,
        sys,
    )

    add_to_expression!(
        container,
        sys,
        PostContingencyBranchFlow,
        FlowActivePowerVariable,
        branches,
        model,
        network_model,
    )

    add_constraints!(
        container,
        sys,
        PostContingencyEmergencyRateLimitConstraint,
        PostContingencyBranchFlow,
        branches,
        model,
        network_model,
    )

    add_feedforward_constraints!(container, model, devices)
    objective_function!(container, devices, model, SecurityConstrainedPTDFPowerModel)
    add_constraint_dual!(container, sys, model)
    return
end