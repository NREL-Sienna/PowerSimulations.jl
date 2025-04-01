"""
Min and max limits for post-contingency branch flows for Abstract Branch Formulation and SecurityConstrainedPTDF Network formulation
"""
function get_min_max_limits(
    branch::PSY.ACBranch,
    ::Type{<:PostContingencyRateLimitConstraintB},
    ::Type{<:AbstractBranchFormulation},
    ::NetworkModel{<:AbstractSecurityConstrainedPTDFModel},
) #  -> Union{Nothing, NamedTuple{(:min, :max), Tuple{Float64, Float64}}}
    if PSY.get_rating_b(branch) === nothing
        @warn "Branch $(get_name(branch)) has no 'rating_b' defined. Post-contingency limit is going to be set using normal-operation rating.
            \n Consider to include post-contingency limits using set_rating_b!()."
        return (min = -1 * PSY.get_rating(branch), max = PSY.get_rating(branch))
    end
    return (min = -1 * PSY.get_rating_b(branch), max = PSY.get_rating_b(branch))
end

"""
Add branch post-contingency rate limit constraints for ACBranch considering LODF and Security Constraints
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{PostContingencyRateLimitConstraintB},
    branches::IS.FlattenIteratorWrapper{PSY.ACBranch},
    branches_outages::Vector{T},
    device_model::DeviceModel{T, U},
    network_model::NetworkModel{SecurityConstrainedPTDFPowerModel},
) where {
    T <: PSY.ACBranch,
    U <: AbstractBranchFormulation,
}
    time_steps = get_time_steps(container)
    device_names = [PSY.get_name(d) for d in branches]
    con_lb =
        add_constraints_container!(
            container,
            cons_type(),
            T,
            get_name.(branches_outages),
            device_names,
            time_steps;
            meta = "lb",
        )

    con_ub =
        add_constraints_container!(
            container,
            cons_type(),
            T,
            get_name.(branches_outages),
            device_names,
            time_steps;
            meta = "ub",
        )

    expressions = get_expression(
        container,
        ExpressionKey(PTDFOutagesBranchFlow, T, IS.Optimization.CONTAINER_KEY_EMPTY_META),
    )

    for branch in branches
        b_name = get_name(branch)

        for branch_outage in branches_outages
            #TODO HOW WE SHOULD HANDLE THE EXPRESSIONS AND CONSTRAINTS RELATED TO THE OUTAGE OF THE LINE RESPECT TO ITSELF?
            if branch == branch_outage
                continue
            end
            b_outage_name = get_name(branch_outage)
            limits = get_min_max_limits(
                branch,
                PostContingencyRateLimitConstraintB,
                U,
                network_model,
            )

            for t in time_steps
                con_ub[b_outage_name, b_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[b_outage_name, b_name, t] <=
                        limits.max)
                con_lb[b_outage_name, b_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[b_outage_name, b_name, t] >=
                        limits.min)
            end
        end
    end

    return
end
