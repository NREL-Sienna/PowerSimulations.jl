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
            #TODO HOW WE SHOULD HANDLE THE EXPRESSIONS AND CONSTRAINTS RELATED TO THE OUTAGE OF THE LINE RESPECT TO ITSELF?
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
                    lodf[index_lodf_branch, index_lodf_outage],#lodf[branch_name, branch_outage_name],#
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
            #TODO HOW WE SHOULD HANDLE THE EXPRESSIONS AND CONSTRAINTS RELATED TO THE OUTAGE OF THE LINE RESPECT TO ITSELF?
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
