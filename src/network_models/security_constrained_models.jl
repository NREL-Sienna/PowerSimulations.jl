"""
Min and max limits for post-contingency branch flows for Abstract Branch Formulation and SecurityConstrainedPTDF Network formulation
"""
function get_min_max_limits(
    branch::PSY.ACBranch,
    ::Union{Type{<:PostContingencyRateLimitConstraintB}, Type{<:PostContingencyRateLimitConstraintWithReserves}},
    ::Type{<:AbstractBranchFormulation},
    ::NetworkModel{<:AbstractPTDFModel},
) #  -> Union{Nothing, NamedTuple{(:min, :max), Tuple{Float64, Float64}}}
    if PSY.get_rating_b(branch) === nothing
        @warn "Branch $(get_name(branch)) has no 'rating_b' defined. Post-contingency limit is going to be set using normal-operation rating.
            \n Consider to include post-contingency limits using set_rating_b!()."
        return (min = -1 * PSY.get_rating(branch), max = PSY.get_rating(branch))
    end
    return (min = -1 * PSY.get_rating_b(branch), max = PSY.get_rating_b(branch))
end

function _get_device_post_contingency_dynamic_branch_rating_time_series(
    container::OptimizationContainer,
    param_key::IS.Optimization.OptimizationContainerKey,
    branch_name::String,
    ::NetworkModel{<:AbstractPTDFModel},
)
    try
        param_container = get_parameter(container, param_key)
        mult = get_multiplier_array(param_container)
        device_dynamic_branch_rating_ts =
            get_parameter_column_refs(param_container, branch_name)
        return device_dynamic_branch_rating_ts, mult
    catch e
        @warn "Branch $branch_name has time series but it has no $param_key. Static rating_b parameter wil be used for Post-contingency flow limit"
        return [], []
    end
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
        ExpressionKey(PTDFPostContingencyBranchFlow, T, IS.Optimization.CONTAINER_KEY_EMPTY_META),
    )

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
                PostContingencyRateLimitConstraintB,
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


"""
Add branch post-contingency rate limit constraints for ACBranch considering G-1 security constraints with Reserves
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{PostContingencyRateLimitConstraintWithReserves},
    service::SR,
    branches::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    contributing_devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    device_outages::Union{Vector{V}, IS.FlattenIteratorWrapper{V}},
    service_model::ServiceModel{SR, RangeReserve},
    network_model::NetworkModel{X},
) where {
    SR <: PSY.Service,
    T <: PSY.ACBranch,
    U <: PSY.Device,
    V <: PSY.Device,
    X <: AbstractPTDFModel,
}
    service_name = get_service_name(service_model)
    time_steps = get_time_steps(container)
    branch_names = [PSY.get_name(d) for d in branches]
    con_lb =
        add_constraints_container!(
            container,
            cons_type(),
            T,
            get_name.(device_outages),
            branch_names,
            time_steps;
            meta = "$(service_name)_lb",
        )

    con_ub =
        add_constraints_container!(
            container,
            cons_type(),
            T,
            get_name.(device_outages),
            branch_names,
            time_steps;
            meta = "$(service_name)_ub",
        )

    param_keys = get_parameter_keys(container)

    for branch in branches
        branch_name = get_name(branch)

        expressions = get_expression(
        container,
        ExpressionKey(PTDFPostContingencyBranchFlowWithReserves, typeof(branch), service_name),
        )

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

        for device_outage in device_outages
            device_outage_name = get_name(device_outage)

            limits = get_min_max_limits(
                branch,
                PostContingencyRateLimitConstraintWithReserves,
                AbstractBranchFormulation,
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

                con_ub[device_outage_name, branch_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[device_outage_name, branch_name, t] <=
                        limits.max)
                con_lb[device_outage_name, branch_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[device_outage_name, branch_name, t] >=
                        limits.min)
            end
        end
    end

    return
end