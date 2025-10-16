# TODO - series network reduction elements are currently Vector{Any} (https://github.com/NREL-Sienna/PowerNetworkMatrices.jl/issues/189)
# When this design changes, type signatures should be updated from ::Vector{Any} throughout PSI 
const NETWORK_REDUCTION_MAPS =
    ["direct_branch_map", "series_branch_map", "parallel_branch_map"]

struct BranchReductionOptimizationTracker
    variable_dict::Dict{
        Type{<:PSY.ACTransmission},
        Dict{Type{<:ISOPT.VariableType}, Dict{String, Dict{Int, JuMP.VariableRef}}},
    }
    expression_dict::Dict{
        Tuple{Type{<:PSY.Component}, String},
        Dict{
            Tuple{Type{<:ISOPT.ExpressionType}, Int},
            Dict{String, Dict{Int, JuMP.AffExpr}},
        },
    }
    constraint_dict::Dict{
        Type{<:PSY.ACTransmission},
        Dict{Type{<:ISOPT.ConstraintType}, Vector{String}},
    }
end

get_variable_dict(reduction_tracker::BranchReductionOptimizationTracker) =
    reduction_tracker.variable_dict
get_expression_dict(reduction_tracker::BranchReductionOptimizationTracker) =
    reduction_tracker.expression_dict
get_constraint_dict(reduction_tracker::BranchReductionOptimizationTracker) =
    reduction_tracker.constraint_dict

function BranchReductionOptimizationTracker()
    return BranchReductionOptimizationTracker(Dict(), Dict(), Dict())
end

# TODO: get rid of this function and implement something more efficient without the
# mixed type vector
function _has_keys_nested(nested_dict::Dict, keys::Vector)
    for key in keys
        if haskey(nested_dict, key)
            nested_dict = nested_dict[key]
        else
            return false
        end
    end
    return true
end

function _search_for_reduced_branch_expression(
    ::BranchReductionOptimizationTracker,
    ::PSY.ACTransmission,
    ::Type{U},
    ::String,
    ::Type{T},
    ::Int,
    t::Int,
) where {
    T <: PostContingencyExpressions,
    U <: PSY.Component,
}
    return (false, EMPTY_BRANCH_NAME_MATCH)
end

function _search_for_reduced_branch_expression(
    ::BranchReductionOptimizationTracker,
    ::Set{PSY.ACTransmission},
    ::Type{U},
    ::String,
    ::Type{T},
    ::Int,
    t::Int,
) where {
    T <: PostContingencyExpressions,
    U <: PSY.Component}
    return (false, EMPTY_BRANCH_NAME_MATCH)
end

function _search_for_reduced_branch_expression(
    reduction_tracker::BranchReductionOptimizationTracker,
    series_chain::Vector{Any},
    component_type::Type{U},
    component_name::String,
    expression_type::Type{T},
    expression_stage::Int,
    t::Int,
) where {
    T <: PostContingencyExpressions,
    U <: PSY.Component,
}
    reduced_branch_expression_tracker = get_expression_dict(reduction_tracker)
    for segment in series_chain
        segment_type = _get_segment_type(segment)
        segment_names = _get_branch_names(segment)
        if segment_type == U
            if _has_keys_nested(
                reduced_branch_expression_tracker,
                [
                    (component_type, component_name),
                    (expression_type, expression_stage),
                    first(segment_names),
                    t,
                ],
            )
                return (true, first(segment_names))
            end
        end
    end
    return (false, EMPTY_BRANCH_NAME_MATCH)
end

function _search_for_reduced_branch_variable(
    ::BranchReductionOptimizationTracker,
    ::Set{PSY.ACTransmission},
    ::Type{T},
    ::Type{U},
    t,
) where {
    T <: AbstractACActivePowerFlow,
    U <: PSY.ACBranch}
    return (false, EMPTY_BRANCH_NAME_MATCH)
end

function _search_for_reduced_branch_variable(
    ::BranchReductionOptimizationTracker,
    ::PSY.ACTransmission,
    ::Type{T},
    ::Type{U},
    t,
) where {
    T <: AbstractACActivePowerFlow,
    U <: PSY.ACBranch}
    return (false, EMPTY_BRANCH_NAME_MATCH)
end

function _search_for_reduced_branch_variable(
    reduction_tracker::BranchReductionOptimizationTracker,
    series_chain::Vector{Any},
    ::Type{T},
    ::Type{U},
    t::Int,
) where {
    T <: AbstractACActivePowerFlow,
    U <: PSY.ACBranch}
    reduced_branch_variable_tracker = get_variable_dict(reduction_tracker)
    for segment in series_chain
        segment_type = _get_segment_type(segment)
        segment_names = _get_branch_names(segment)
        if segment_type == U
            if _has_keys_nested(
                reduced_branch_variable_tracker,
                [U, T, first(segment_names), t],
            )
                return (true, first(segment_names))
            end
        end
    end
    return (false, EMPTY_BRANCH_NAME_MATCH)
end

function _add_expression_to_tracker!(
    ::BranchReductionOptimizationTracker,
    ::JuMP.AffExpr,
    ::PSY.ACTransmission,
    ::Type{U},
    ::String,
    ::Type{T},
    ::Int,
    t::Int,
) where {
    T <: PostContingencyExpressions,
    U <: PSY.Component,
}
    return
end

function _add_expression_to_tracker!(
    ::BranchReductionOptimizationTracker,
    ::JuMP.AffExpr,
    ::Set{PSY.ACTransmission},
    ::Type{U},
    ::String,
    ::Type{T},
    ::Int,
    t::Int,
) where {
    T <: PostContingencyExpressions,
    U <: PSY.Component,
}
    return
end

function _add_expression_to_tracker!(
    reduction_tracker::BranchReductionOptimizationTracker,
    expression::JuMP.AffExpr,
    reduction_entry::Vector{Any},
    component_type::Type{U},
    component_name::String,
    expression_type::Type{T},
    expression_stage::Int,
    t::Int,
) where {
    T <: PostContingencyExpressions,
    U <: PSY.Component,
}
    for segment in reduction_entry
        segment_names = _get_branch_names(segment)
        for segment_name in segment_names
            _add_to_expression_tracker!(
                reduction_tracker,
                expression,
                component_type,
                component_name,
                expression_type,
                expression_stage,
                segment_name,
                t,
            )
        end
    end
    return
end

function _add_to_expression_tracker!(
    reduction_tracker::BranchReductionOptimizationTracker,
    expression::JuMP.AffExpr,
    component_type::Type{U},
    component_name::String,
    expression_type::Type{T},
    expression_stage::Int,
    segment_name::String,
    t::Int,
) where {
    T <: PostContingencyExpressions,
    U <: PSY.Component,
}
    reduced_branch_expression_tracker = get_expression_dict(reduction_tracker)
    level_1_map = get!(
        reduced_branch_expression_tracker,
        (component_type, component_name),
        Dict{
            Tuple{Type{<:ISOPT.ExpressionType}, Int},
            Dict{String, Dict{Int, JuMP.AffExpr}},
        }(),
    )
    level_2_map =
        get!(
            level_1_map,
            (expression_type, expression_stage),
            Dict{String, Dict{Int, JuMP.AffExpr}}(),
        )
    level_3_map = get!(level_2_map, segment_name, Dict{Int, JuMP.AffExpr}())
    level_3_map[t] = expression
    return
end

function _add_variable_to_tracker!(
    ::BranchReductionOptimizationTracker,
    variable::JuMP.VariableRef,
    reduction_entry::Set{PSY.ACTransmission},
    ::Type{U},
    t,
) where {
    U <: AbstractACActivePowerFlow,
}
    return
end
function _add_variable_to_tracker!(
    ::BranchReductionOptimizationTracker,
    variable::JuMP.VariableRef,
    reduction_entry::PSY.ACTransmission,
    ::Type{U},
    t,
) where {U <: AbstractACActivePowerFlow}
    return
end

function _add_variable_to_tracker!(
    reduction_tracker::BranchReductionOptimizationTracker,
    variable::JuMP.VariableRef,
    series_chain::Vector{Any},
    variable_type::Type{<:AbstractACActivePowerFlow},
    t::Int,
)
    for segment in series_chain
        segment_type = _get_segment_type(segment)
        segment_names = _get_branch_names(segment)
        for segment_name in segment_names
            _add_to_variable_tracker!(
                reduction_tracker,
                segment_type,
                variable_type,
                segment_name,
                variable,
                t,
            )
        end
    end
    return
end

function _add_to_variable_tracker!(
    reduction_tracker::BranchReductionOptimizationTracker,
    segment_type::Type{T},
    variable_type::Type{U},
    segment_name::String,
    variable::JuMP.VariableRef,
    t::Int,
) where {
    T <: PSY.ACTransmission,
    U <: AbstractACActivePowerFlow,
}
    reduced_branch_variable_tracker = get_variable_dict(reduction_tracker)
    level_1_map = get!(
        reduced_branch_variable_tracker,
        segment_type,
        Dict{
            Type{<:ISOPT.VariableType},
            Dict{String, Dict{Int, JuMP.VariableRef}},
        }(),
    )
    level_2_map =
        get!(level_1_map, variable_type, Dict{String, Dict{Int, JuMP.VariableRef}}())
    level_3_map = get!(level_2_map, segment_name, Dict{Int, JuMP.VariableRef}())
    level_3_map[t] = variable
    return
end
_get_segment_type(::T) where {T <: PSY.ACBranch} = T
_get_segment_type(tfw_tuple::Tuple{PSY.ThreeWindingTransformer, Int}) =
    typeof(first(tfw_tuple))
_get_segment_type(x::Set) = typeof(first(x))

function get_branch_name_constraint_axis(
    modeled_branch_types::Vector{DataType},
    nrd::PNM.NetworkReductionData,
    all_branch_maps_by_type::Dict,
    ::Type{U},
    reduction_tracker::BranchReductionOptimizationTracker,
) where {U <: ISOPT.ConstraintType}
    ac_transmission_types = PNM.get_ac_transmission_types(nrd)
    name_axis = Vector{String}()
    for ac_type in ac_transmission_types
        (ac_type ∉ modeled_branch_types) && continue
        name_axis_by_type = Vector{String}()
        for map_name in NETWORK_REDUCTION_MAPS
            map = all_branch_maps_by_type[map_name]
            !haskey(map, ac_type) && continue
            for entry in values(map[ac_type])
                _add_names_to_axis!(name_axis, entry, ac_type, U, reduction_tracker)
            end
        end
        vcat(name_axis, name_axis_by_type)
    end
    return name_axis
end

function get_branch_name_constraint_axis(
    all_branch_maps_by_type::Dict,
    ::Type{T},
    ::Type{U},
    reduction_tracker::BranchReductionOptimizationTracker,
) where {T <: PSY.ACBranch, U <: ISOPT.ConstraintType}
    name_axis = Vector{String}()
    for map_name in NETWORK_REDUCTION_MAPS
        map = all_branch_maps_by_type[map_name]
        !haskey(map, T) && continue
        for entry in values(map[T])
            _add_names_to_axis!(name_axis, entry, T, U, reduction_tracker)
        end
    end
    return name_axis
end

function get_branch_name_variable_axis(nrd::PNM.NetworkReductionData)
    ac_transmission_types = PNM.get_ac_transmission_types(nrd)
    all_branch_maps_by_type = nrd.all_branch_maps_by_type
    name_axis = Vector{String}()
    for T in ac_transmission_types
        names_by_type = get_branch_name_variable_axis(all_branch_maps_by_type, T)
        name_axis = vcat(name_axis, names_by_type) # TODO change implementation to avoid repeated concatenating - Matt
    end
    return name_axis
end

function get_branch_name_variable_axis(
    all_branch_maps_by_type::Dict,
    ::Type{T},
) where {T <: PSY.ACBranch}
    name_axis = Vector{String}()
    for map_name in NETWORK_REDUCTION_MAPS
        !(_has_keys_nested(all_branch_maps_by_type, [map_name, T])) && continue
        for entry in values(all_branch_maps_by_type[map_name][T])
            _add_names_to_axis!(name_axis, entry, T)
        end
    end
    return name_axis
end

function _add_names_to_axis!(name_axis::Vector{String}, name_override::String)
    push!(name_axis, name_override)
    return
end

function _add_names_to_axis!(
    name_axis::Vector{String},
    entry::T,
    ::Type{T},
) where {T <: PSY.ACBranch}
    push!(name_axis, PSY.get_name(entry))
    return
end

function _add_names_to_axis!(
    name_axis,
    entry::Set,
    ::Type{T},
) where {T <: PSY.ACBranch}
    for branch in entry
        name = PSY.get_name(branch) * "_double_circuit"
        _add_names_to_axis!(name_axis, name)
    end
    return
end

function _add_names_to_axis!(
    name_axis,
    entry::Vector{Any},
    ::Type{T},
) where {T <: PSY.ACBranch}
    for segment in entry
        # Need to check type because a series chain could have elements of different types:
        if _get_segment_type(segment) == T
            _add_names_to_axis!(name_axis, segment, T)
        end
    end
    return
end

function has_existing_constraint(
    name::String,
    ::Type{T},
    ::Type{U},
    reduction_tracker::BranchReductionOptimizationTracker,
) where {T <: PSY.ACBranch, U <: ISOPT.ConstraintType}
    reduced_branch_constraint_tracker = get_constraint_dict(reduction_tracker)
    rb1 = get!(
        reduced_branch_constraint_tracker,
        T,
        Dict{Type{<:ISOPT.ConstraintType}, Vector{String}}(),
    )
    names = get!(rb1, U, Vector{String}())
    return name in names
end

# If you are in the direct branch map, cannot already have a constraint
function _add_names_to_axis!(
    name_axis,
    entry::T,
    ::Type{T},
    ::Type{U},
    ::BranchReductionOptimizationTracker,
) where {T <: PSY.ACBranch, U <: ISOPT.ConstraintType}
    push!(name_axis, PSY.get_name(entry))
    return
end

# If you are in the parallel branch map, cannot already have a constraint.
function _add_names_to_axis!(
    name_axis::Vector{String},
    entry::Set,
    ::Type{T},
    ::Type{U},
    ::BranchReductionOptimizationTracker,
) where {T <: PSY.ACBranch, U <: ISOPT.ConstraintType}
    modeled_circuit = first(entry)
    name = PSY.get_name(modeled_circuit) * "_double_circuit"
    _add_names_to_axis!(name_axis, name)
    return
end

function _add_names_to_axis!(
    name_axis::Vector{String},
    entry::Vector{Any},
    x::Type{T},
    y::Type{U},
    reduction_tracker::BranchReductionOptimizationTracker,
) where {T <: PSY.ACBranch, U <: ISOPT.ConstraintType}
    constraint_added = false
    branch_names_in_d2_chain = _get_branch_names(entry)
    reduced_branch_constraint_tracker = get_constraint_dict(reduction_tracker)
    for name in branch_names_in_d2_chain
        if has_existing_constraint(name, x, y, reduction_tracker)
            return
        end
    end
    for segment in entry
        # Need to check type because a series chain could have elements of different types:
        if _get_segment_type(segment) == T
            if !constraint_added
                _add_names_to_axis!(
                    name_axis,
                    segment,
                    x,
                    y,
                    reduction_tracker,
                )
                constraint_added = true
            end
        else
            segment_names = _get_branch_names(segment)
            rb1 = get!(
                reduced_branch_constraint_tracker,
                _get_segment_type(segment),
                Dict{Type{<:ISOPT.ConstraintType}, Vector{String}}(),
            )
            rb2 = get!(rb1, y, Vector{String}())
            [push!(rb2, name) for name in segment_names]
        end
    end
    return
end

function _get_branch_names(entry::T) where {T <: PSY.ACBranch}
    return [PSY.get_name(entry)]
end

function _get_branch_names(entry::Set)
    return [PSY.get_name(x) * "_double_circuit" for x in entry]
end

function _get_branch_names(entry::Tuple{PSY.ThreeWindingTransformer, Int})
    return [PSY.get_name(first(entry))]
end

function _get_branch_names(entry::Vector{Any})
    branch_names = Vector{String}()
    for segment in entry
        branch_names = vcat(branch_names, _get_branch_names(segment))
    end
    return branch_names
end
