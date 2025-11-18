# TODO - error if a the outage is associated with a reduced branch in N-1 formulation

"""
Add branch post-contingency rate limit constraints for ACBranch considering LODF and Security Constraints
"""
function add_constraints!(
    container::OptimizationContainer,
    sys::PSY.System,
    cons_type::Type{T},
    device_model::DeviceModel{V, U},
    network_model::NetworkModel{X},
) where {
    T <: PostContingencyEmergencyFlowRateConstraint,
    V <: PSY.ACTransmission,
    U <: AbstractSecurityConstrainedStaticBranch,
    X <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)

    associated_outages = PSY.get_associated_supplemental_attributes(
        sys,
        V;
        attribute_type = PSY.UnplannedOutage,
    )

    net_reduction_data = network_model.network_reduction
    all_branch_maps_by_type = PNM.get_all_branch_maps_by_type(net_reduction_data)
    reduced_branch_tracker = get_reduced_branch_tracker(network_model)

    modeled_branch_types = network_model.modeled_branch_types

    branches_names = get_branch_argument_constraint_axis(
        net_reduction_data,
        reduced_branch_tracker,
        modeled_branch_types,
        PostContingencyEmergencyFlowRateConstraint,
    )

    con_lb =
        add_constraints_container!(
            container,
            T(),
            V,
            string.(IS.get_uuid.(associated_outages)),
            branches_names,
            time_steps;
            meta = "lb",
        )

    con_ub =
        add_constraints_container!(
            container,
            T(),
            V,
            string.(IS.get_uuid.(associated_outages)),
            branches_names,
            time_steps;
            meta = "ub",
        )

    expressions = get_expression(container, PostContingencyBranchFlow(), V)

    #Deactivating PostContingencyDynamicBranchRatingTimeSeriesParameter for now
    #param_keys = get_parameter_keys(container)
    # param_key = ParameterKey(
    #     PostContingencyDynamicBranchRatingTimeSeriesParameter,
    #     typeof(branch),
    # )
    for outage in associated_outages
        outage_id = string(IS.get_uuid(outage))
        associated_devices =
            PSY.get_associated_components(
                sys,
                outage;
                component_type = V,
            )
        contingency_device = first(associated_devices)
        contingency_device_name = PSY.get_name(contingency_device)

        for b_type in modeled_branch_types
            if !haskey(
                get_constraint_map_by_type(reduced_branch_tracker)[FlowRateConstraint],
                b_type,
            )
                continue
            end

            for (name, (arc, reduction)) in
                get_constraint_map_by_type(reduced_branch_tracker)[FlowRateConstraint][b_type]
                reduction_entry = all_branch_maps_by_type[reduction][b_type][arc]
                limits =
                    get_scuc_min_max_limits(reduction_entry, T, U)
                for t in time_steps
                    con_ub[outage_id, name, t] =
                        JuMP.@constraint(get_jump_model(container),
                            expressions[outage_id, name, t] <=
                            limits.max)
                    con_lb[outage_id, name, t] =
                        JuMP.@constraint(get_jump_model(container),
                            expressions[outage_id, name, t] >=
                            limits.min)
                end
            end
        end
    end
    return
end

function add_post_contingency_flow_expressions!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    model::DeviceModel{V, F},
    network_model::NetworkModel{N},
) where {
    T <: PostContingencyBranchFlow,
    V <: PSY.ACTransmission,
    F <: AbstractSecurityConstrainedStaticBranch,
    N <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    lodf = get_LODF_matrix(network_model)

    associated_outages = PSY.get_associated_supplemental_attributes(
        sys,
        V;
        attribute_type = PSY.UnplannedOutage,
    )

    net_reduction_data = network_model.network_reduction
    reduced_branch_tracker = get_reduced_branch_tracker(network_model)

    modeled_branch_types = network_model.modeled_branch_types

    branches_names = get_branch_argument_constraint_axis(
        net_reduction_data,
        reduced_branch_tracker,
        modeled_branch_types,
        PostContingencyEmergencyFlowRateConstraint,
    )

    expression_container = add_expression_container!(
        container,
        T(),
        V,
        string.(IS.get_uuid.(associated_outages)),
        branches_names,
        time_steps,
    )

    jump_model = get_jump_model(container)

    precontingency_outage_flow_variables = get_variable(
        container,
        FlowActivePowerVariable(),
        V,
    )

    for b_type in modeled_branch_types
        if !haskey(
            get_constraint_map_by_type(reduced_branch_tracker)[FlowRateConstraint],
            b_type,
        )
            continue
        end

        pre_contingency_flow =
            get_variable(container, FlowActivePowerVariable(), b_type)
        name_to_arc_map =
            get_constraint_map_by_type(reduced_branch_tracker)[FlowRateConstraint][b_type]

        for outage in associated_outages
            outage_id = string(IS.get_uuid(outage))
            associated_devices =
                PSY.get_associated_components(
                    sys,
                    outage;
                    component_type = V,
                )
            contingency_device = first(associated_devices)
            contingency_device_name = PSY.get_name(contingency_device)
            if length(associated_devices) != 1
                @warn(
                    "Outage $(outage_id) is associated with $(length(associated_devices)) devices of type $V. Expected only one associated device per outage for contingency analysis. It is being considered only component $(PSY.get_name(contingency_device_name))."
                )
            end
            index_lodf_outage = (contingency_device.arc.from.number,
                contingency_device.arc.to.number,
            )
            contingency_variables =
                precontingency_outage_flow_variables[contingency_device_name, :]

            tasks = map(collect(name_to_arc_map)) do pair
                (name, (arc, _)) = pair
                lodf_factor = lodf[arc, index_lodf_outage]
                Threads.@spawn _make_branch_scuc_postcontingency_flow_expressions!(
                    jump_model,
                    name,
                    outage_id,
                    time_steps,
                    lodf_factor,
                    contingency_variables.data,
                    pre_contingency_flow,
                )
            end
            for task in tasks
                name, expressions = fetch(task)
                expression_container[outage_id, name, :] .= expressions
            end
        end
    end

    #= Leaving serial code commented out for debugging purposes in the future
    for b_type in modeled_branch_types
        if !haskey(
            get_constraint_map_by_type(reduced_branch_tracker)[FlowRateConstraint],
            b_type,
        )
            continue
        end

        pre_contingency_flow =
            get_variable(container, FlowActivePowerVariable(), b_type)

        for outage in associated_outages
            outage_id = string(IS.get_uuid(outage))
            associated_devices =
                PSY.get_associated_components(
                    sys,
                    outage;
                    component_type = V,
                )
            contingency_device = first(associated_devices)
            contingency_device_name = PSY.get_name(contingency_device)
            if length(associated_devices) != 1
                @warn(
                    "Outage $(outage_id) is associated with $(length(associated_devices)) devices of type $V. Expected only one associated device per outage for contingency analysis. It is being considered only component $(PSY.get_name(contingency_device_name))."
                )
            end
            index_lodf_outage = (contingency_device.arc.from.number,
                contingency_device.arc.to.number,
            )
            contingency_variables =
                precontingency_outage_flow_variables[contingency_device_name, :]

            for (name, (arc, reduction)) in
                get_constraint_map_by_type(reduced_branch_tracker)[FlowRateConstraint][b_type]
                lodf_factor = lodf[arc, index_lodf_outage]
                expression_container[outage_id, name, :] .=
                    _make_branch_scuc_postcontingency_flow_expressions!(
                        jump_model,
                        name,
                        outage_id,
                        time_steps,
                        lodf_factor,
                        contingency_variables.data,
                        pre_contingency_flow,
                    )
            end
        end
    end
    =#
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

    # The order of these methods is important. The add_expressions! must be before the constraints
    add_expressions!(
        container,
        PTDFBranchFlow,
        devices,
        model,
        network_model,
    )

    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraints!(container, FlowRateConstraint, devices, model, network_model)
    add_feedforward_constraints!(container, model, devices)
    objective_function!(container, devices, model, X)
    add_constraint_dual!(container, sys, model)

    associated_outages = PSY.get_associated_supplemental_attributes(
        sys,
        V;
        attribute_type = PSY.UnplannedOutage,
    )

    if isempty(associated_outages)
        @info "No associated outage supplemental attributes found associated with devices: $V. Skipping contingency variable addition for that device type."
        return
    end

    branches = get_available_components(model, sys)

    add_post_contingency_flow_expressions!(
        container,
        sys,
        PostContingencyBranchFlow,
        model,
        network_model,
    )

    add_constraints!(
        container,
        sys,
        PostContingencyEmergencyFlowRateConstraint,
        model,
        network_model,
    )

    return
end
