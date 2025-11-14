"""
Min and max limits for post-contingency branch flows for Abstract Branch Formulation and SecurityConstrainedPTDF Network formulation
"""
function get_min_max_limits(
    branch::PSY.ACTransmission,
    ::Type{<:PostContingencyEmergencyFlowRateConstraint},
    ::Type{<:AbstractBranchFormulation},
    ::NetworkModel{<:AbstractPTDFModel},
)
    if PSY.get_rating_b(branch) === nothing
        @warn "Branch $(get_name(branch)) has no 'rating_b' defined. Post-contingency limit is going to be set using normal-operation rating.
            \n Consider including post-contingency limits using set_rating_b!()."
        return (min = -1 * PSY.get_rating(branch), max = PSY.get_rating(branch))
    end
    return (min = -1 * PSY.get_rating_b(branch), max = PSY.get_rating_b(branch))
end

"""
Add branch post-contingency rate limit constraints for ACBranch considering LODF and Security Constraints
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{PostContingencyEmergencyFlowRateConstraint},
    branches::IS.FlattenIteratorWrapper{PSY.ACTransmission},
    branches_outages::Vector{T},
    device_model::DeviceModel{T, U},
    network_model::NetworkModel{V},
) where {
    T <: PSY.ACTransmission,
    U <: AbstractBranchFormulation,
    V <: AbstractSecurityConstrainedPTDFModel,
}
    time_steps = get_time_steps(container)
    device_names = PSY.get_name.(devices)

    con_lb = add_constraints_container!(
        container,
        cons_type(),
        T,
        get_name.(branches_outages),
        device_names,
        time_steps;
        meta = "lb",
    )

    con_ub = add_constraints_container!(
        container,
        cons_type(),
        T,
        get_name.(branches_outages),
        device_names,
        time_steps;
        meta = "ub",
    )

    expressions = get_expression(container, PostContingencyBranchFlow(), T)

    param_keys = get_parameter_keys(container)

    for branch in branches
        branch_name = get_name(branch)

        param_key = ParameterKey(
            PostContingencyDynamicBranchRatingTimeSeriesParameter,
            typeof(branch),
        )
        has_dlr_ts = (param_key in param_keys) && PSY.has_time_series(branch)

        device_dynamic_branch_rating_ts = []
        if has_dlr_ts
            device_dynamic_branch_rating_ts, mult =
                _get_device_post_contingency_dynamic_branch_rating_time_series(
                    container,
                    param_key,
                    branch_name,
                    network_model)
        end

        for branch_outage in branches_outages
            #TODO HOW WE SHOULD HANDLE THE EXPRESSIONS AND CONSTRAINTS RELATED TO THE OUTAGE OF THE LINE RESPECT TO ITSELF?
            if branch == branch_outage
                continue
            end

            b_outage_name = get_name(branch_outage)

            limits = get_min_max_limits(
                branch,
                PostContingencyEmergencyFlowRateConstraint,
                U,
                network_model,
            )

            for t in time_steps
                # device_dynamic_branch_rating_ts is empty if this device doesn't have a time series
                if !isempty(device_dynamic_branch_rating_ts)
                    limits = (
                        min = -1 * device_dynamic_branch_rating_ts[t] *
                              mult[branch_name, t],
                        max = device_dynamic_branch_rating_ts[t] * mult[branch_name, t],
                    ) #update limits
                end

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
