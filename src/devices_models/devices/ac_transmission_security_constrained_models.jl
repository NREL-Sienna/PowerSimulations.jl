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

    # Deactivating this since it does not seem that the industry or we have data for this
    #param_keys = get_parameter_keys(container)
    # param_key = ParameterKey(
    #     PostContingencyDynamicBranchRatingTimeSeriesParameter,
    #     typeof(branch),
    # )
    for outage in associated_outages
        outage_id = string(IS.get_uuid(outage))

        for b_type in modeled_branch_types
            if !haskey(
                get_constraint_map_by_type(reduced_branch_tracker)[PostContingencyEmergencyFlowRateConstraint],
                b_type,
            )
                continue
            end
            name_to_arc_map =
                get_constraint_map_by_type(reduced_branch_tracker)[PostContingencyEmergencyFlowRateConstraint][b_type]
            for (name, (arc, reduction)) in name_to_arc_map
                reduction_entry = all_branch_maps_by_type[reduction][b_type][arc]
                limits =
                    get_emergency_min_max_limits(reduction_entry, T, U)
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

function _check_outage_data_branch_scuc(
    length_associated_devices::Int64,
    contingency_device_name::String,
    contingency_device_key::String,
    outage_id::String,
    V::Type{<:PSY.ACTransmission},
    name_to_arc_map_contingency::Dict{String, String},
)
    if length_associated_devices != 1
        @warn "Outage $(outage_id) is associated with $(length_associated_devices) devices of type $V. Expected only one associated device per outage for contingency analysis. Only component $contingency_device_name is being considered." maxlog =
            100
    end

    if !haskey(name_to_arc_map_contingency, contingency_device_name)
        error(
            "An outage was added to branch $contingency_device_name of type $V, but this case is not supported yet by the reductions algorithms.",
        )
    end
    #Check if branch was reduced
    if contingency_device_key != contingency_device_name
        if V == PSY.PhaseShiftingTransformer
            error(
                "An outage was added to branch $contingency_device_name of type $V, but this case is not supported yet by the reductions algorithms.",
            )
        end
        @warn "Outage $outage_id was added to branch $contingency_device_name of type $V, but this branch has been reduced.\nThe outage will be treated as affecting all the reduced components $contingency_device_key." maxlog =
            100
    end
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

    name_to_arc_map_contingency =
        PNM.get_component_to_reduction_name_map(net_reduction_data, V)
    jump_model = get_jump_model(container)

    for b_type in modeled_branch_types
        if !haskey(
            get_constraint_map_by_type(reduced_branch_tracker)[PostContingencyEmergencyFlowRateConstraint],
            b_type,
        )
            continue
        end
        pre_contingency_flow =
            get_expression(container, PTDFBranchFlow(), b_type)
        name_to_arc_map =
            get_constraint_map_by_type(reduced_branch_tracker)[PostContingencyEmergencyFlowRateConstraint][b_type]

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
            contingency_device_key = name_to_arc_map_contingency[contingency_device_name]

            _check_outage_data_branch_scuc(
                length(associated_devices),
                contingency_device_name,
                contingency_device_key,
                outage_id,
                V,
                name_to_arc_map_contingency,
            )

            from_number = PSY.get_number(PSY.get_from(PSY.get_arc(contingency_device)))
            to_number = PSY.get_number(PSY.get_to(PSY.get_arc(contingency_device)))
            index_lodf_outage = (from_number, to_number)

            precontingency_outage_flow =
                get_expression(container, PTDFBranchFlow(), V)[contingency_device_key, :]

            tasks = map(collect(name_to_arc_map)) do pair
                (name, (arc, _)) = pair
                lodf_factor = lodf[arc, index_lodf_outage]
                Threads.@spawn _make_branch_scuc_postcontingency_flow_expressions!(
                    jump_model,
                    name,
                    outage_id,
                    time_steps,
                    lodf_factor,
                    precontingency_outage_flow,
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

        pre_contingency_flow =
            get_expression(container, PTDFBranchFlow(), b_type)

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
            contingency_device_key = name_to_arc_map_contingency[contingency_device_name]

            _check_outage_data_branch_scuc(
                length(associated_devices),
                contingency_device_name,
                contingency_device_key,
                outage_id,
                V,
                name_to_arc_map_contingency,
            )
            from_number = PSY.get_number(PSY.get_from(PSY.get_arc(contingency_device)))
            to_number = PSY.get_number(PSY.get_to(PSY.get_arc(contingency_device)))
            index_lodf_outage = (from_number, to_number)

            precontingency_outage_flow =
                get_expression(container, PTDFBranchFlow(), V)[contingency_device_key, :]

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
                        precontingency_outage_flow,
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
    device_model::DeviceModel{T, F},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: PSY.ACTransmission, F <: AbstractSecurityConstrainedStaticBranch}
    devices = get_available_components(device_model, sys)
    if get_use_slacks(device_model)
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

    if haskey(get_time_series_names(device_model), DynamicBranchRatingTimeSeriesParameter)
        add_parameters!(
            container,
            DynamicBranchRatingTimeSeriesParameter,
            devices,
            device_model,
        )
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

    add_feedforward_arguments!(container, device_model, devices)

    # The order of these methods is important. The add_expressions! must be before the constraints
    # Since now there is no FlowVariable this expression must be added in the ArgumentConstructStage to ensure all expressions are created before the constraints
    add_expressions!(
        container,
        PTDFBranchFlow,
        devices,
        device_model,
        network_model,
    )

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    device_model::DeviceModel{V, F},
    network_model::NetworkModel{X},
) where {
    V <: PSY.ACTransmission,
    F <: AbstractSecurityConstrainedStaticBranch,
    X <: AbstractPTDFModel,
}
    devices = get_available_components(device_model, sys)

    add_constraints!(container, FlowRateConstraint, devices, device_model, network_model)
    add_feedforward_constraints!(container, device_model, devices)
    objective_function!(container, devices, device_model, X)
    add_constraint_dual!(container, sys, device_model)

    associated_outages = PSY.get_associated_supplemental_attributes(
        sys,
        V;
        attribute_type = PSY.UnplannedOutage,
    )

    if isempty(associated_outages)
        @info "No associated outage supplemental attributes found associated with devices: $V. Skipping contingency variable addition for that device type."
        return
    end

    branches = get_available_components(device_model, sys)

    add_post_contingency_flow_expressions!(
        container,
        sys,
        PostContingencyBranchFlow,
        device_model,
        network_model,
    )

    add_constraints!(
        container,
        sys,
        PostContingencyEmergencyFlowRateConstraint,
        device_model,
        network_model,
    )

    return
end
