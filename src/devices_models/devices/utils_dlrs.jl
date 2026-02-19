
# ----------------------------------------------------------
# ------ RATING FUNCTIONS FOR DYNAMIC BRANCH RATINGS -------
# ----------------------------------------------------------
"""
    get_equivalent_dynamic_branch_rating(param_container::ParameterContainer, branch::PSY.ACTransmission, ts_name::String, ts_type::DataType, t::Int, ci_name::String, mult)

Calculate the total rating for PSY.ACTransmission branches that contain Dynamic Branch Rating Time Series.
"""
function get_equivalent_dynamic_branch_rating(
    param_container::ParameterContainer,
    branch::U,
    ts_name::String,
    ts_type::DataType,
    t::Int,
    ci_name::String,
    mult,
) where {U <: PSY.ACTransmission}
    if PSY.has_time_series(branch, ts_type, ts_name)
        branch_dlr_params = get_parameter_column_refs(param_container, get_name(branch))
        return branch_dlr_params[t] * mult[get_name(branch), t]
    end

    return PSY.get_rating(branch)
end

"""
    get_equivalent_dynamic_branch_rating(param_container::ParameterContainer, bp::PNM.BranchesParallel{<:PSY.ACTransmission}, ts_name::String, ts_type::DataType, t::Int, ci_name::String, mult)

Calculate the total rating for branches in parallel that contain Dynamic Branch Rating Time Series.
For parallel circuits, the rating is the sum of individual ratings divided by the number of circuits.
This provides a conservative estimate that accounts for potential overestimation of total capacity.
"""
function get_equivalent_dynamic_branch_rating(
    param_container::ParameterContainer,
    bp::PNM.BranchesParallel{<:PSY.ACTransmission},
    ts_name::String,
    ts_type::DataType,
    t::Int,
    ci_name::String,
    mult,
)
    return sum(
        get_equivalent_dynamic_branch_rating(
            param_container,
            branch,
            ts_name,
            ts_type,
            t,
            ci_name,
            mult,
        ) for branch in bp.branches
    ) / length(bp.branches)
end

"""
    get_equivalent_dynamic_branch_rating(param_container::ParameterContainer, bs::PNM.BranchesSeries, ts_name::String, ts_type::DataType, t::Int, ci_name::String, mult)

Calculate the rating for branches in series that contain Dynamic Branch Rating Time Series.
For series circuits, the rating is limited by the weakest link: Rating_total = min(Rating1, Rating2, ..., Ratingn)
"""
function get_equivalent_dynamic_branch_rating(
    param_container::ParameterContainer,
    bs::PNM.BranchesSeries,
    ts_name::String,
    ts_type::DataType,
    t::Int,
    ci_name::String,
    mult,
)
    return minimum(
        get_equivalent_dynamic_branch_rating(
            param_container,
            branch,
            ts_name,
            ts_type,
            t,
            ci_name,
            mult,
        ) for branch in bs.branches
    )
end

"""
Min and max limits considering dynamic branch ratings for Abstract Branch Formulation
"""
function get_dynamic_branch_rating_min_max_limits(
    param_container::ParameterContainer,
    branch::U,
    ts_name::String,
    ts_type::DataType,
    t::Int,
    ci_name::String,
    mult,
) where {U <: PSY.ACTransmission}
    equivalent_rating = get_equivalent_dynamic_branch_rating(
        param_container,
        branch,
        ts_name,
        ts_type,
        t,
        ci_name,
        mult,
    )
    return (min = -1 * equivalent_rating, max = equivalent_rating)
end

"""
Min and max limits considering dynamic branch ratings for Abstract Branch Formulation
"""
function get_dynamic_branch_rating_min_max_limits(
    param_container::ParameterContainer,
    bp::PNM.BranchesParallel{<:PSY.ACTransmission},
    ts_name::String,
    ts_type::DataType,
    t::Int,
    ci_name::String,
    mult,
)
    equivalent_rating = get_equivalent_dynamic_branch_rating(
        param_container,
        bp,
        ts_name,
        ts_type,
        t,
        ci_name,
        mult,
    )
    return (min = -1 * equivalent_rating, max = equivalent_rating)
end

"""
Min and max limits considering dynamic branch ratings for Abstract Branch Formulation
"""
function get_dynamic_branch_rating_min_max_limits(
    param_container::ParameterContainer,
    bs::PNM.BranchesSeries,
    ts_name::String,
    ts_type::DataType,
    t::Int,
    ci_name::String,
    mult,
)
    equivalent_rating = get_equivalent_dynamic_branch_rating(
        param_container,
        bs,
        ts_name,
        ts_type,
        t,
        ci_name,
        mult,
    )
    return (min = -1 * equivalent_rating, max = equivalent_rating)
end

"""
Min and max limits considering dynamic branch ratings for Abstract Branch Formulation
"""
function get_dynamic_branch_rating_min_max_limits(
    param_container::ParameterContainer,
    transformer_entry::PNM.ThreeWindingTransformerWinding,
    ts_name::String,
    ts_type::DataType,
    t::Int,
    ci_name::String,
    mult,
) #  -> Union{Nothing, NamedTuple{(:min, :max), Tuple{Float64, Float64}}}
    return get_min_max_limits(
        transformer_entry,
        FlowRateConstraint,
        StaticBranch,
    )
end

"""
Min and max limits considering dynamic branch ratings for monitored line
"""
function get_dynamic_branch_rating_min_max_limits(
    param_container::ParameterContainer,
    device::PSY.MonitoredLine,
    ts_name::String,
    ts_type::DataType,
    t::Int,
    ci_name::String,
    mult,
)
    return get_min_max_limits(
        device,
        FlowRateConstraint,
        StaticBranch,
    )
end
