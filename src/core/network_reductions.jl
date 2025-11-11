mutable struct BranchReductionOptimizationTracker
    variable_dict::Dict{
        Type{<:ISOPT.VariableType},
        Dict{Tuple{Int, Int}, Vector{JuMP.VariableRef}},
    }
    constraint_dict::Dict{Type{<:ISOPT.ConstraintType}, Set{Tuple{Int, Int}}}
    constraint_map_by_type::Dict{
        Type{<:ISOPT.ConstraintType},
        Dict{
            Type{<:PSY.ACTransmission},
            SortedDict{String, Tuple{Tuple{Int, Int}, String}},
        },
    }
    number_of_steps::Int
end

get_variable_dict(reduction_tracker::BranchReductionOptimizationTracker) =
    reduction_tracker.variable_dict
get_constraint_dict(reduction_tracker::BranchReductionOptimizationTracker) =
    reduction_tracker.constraint_dict
get_constraint_map_by_type(reduction_tracker::BranchReductionOptimizationTracker) =
    reduction_tracker.constraint_map_by_type

get_number_of_steps(reduction_tracker::BranchReductionOptimizationTracker) =
    reduction_tracker.number_of_steps
set_number_of_steps!(reduction_tracker, number_of_steps) =
    reduction_tracker.number_of_steps = number_of_steps

Base.isempty(
    reduction_tracker::BranchReductionOptimizationTracker,
) = isempty(reduction_tracker.variable_dict) &&
isempty(reduction_tracker.constraint_dict)

Base.empty!(
    reduction_tracker::BranchReductionOptimizationTracker,
) = begin
    empty!(reduction_tracker.variable_dict)
    empty!(reduction_tracker.constraint_dict)
end

function BranchReductionOptimizationTracker()
    return BranchReductionOptimizationTracker(Dict(), Dict(), Dict(), 0)
end

function _make_empty_tracker_dict(arc_tuple::Tuple{Int, Int}, num_steps::Int)
    return Dict{Tuple{Int, Int}, Vector{JuMP.VariableRef}}(
        arc_tuple => Vector{JuMP.VariableRef}(undef, num_steps),
    )
end

function search_for_reduced_branch_variable!(
    tracker::BranchReductionOptimizationTracker,
    arc_tuple::Tuple{Int, Int},
    ::Type{T},
) where {
    T <: VariableType,
}
    variable_dict = tracker.variable_dict

    time_steps = get_number_of_steps(tracker)
    if !haskey(variable_dict, T)
        variable_dict[T] = _make_empty_tracker_dict(arc_tuple, time_steps)
        return (false, variable_dict[T][arc_tuple])
    else
        if haskey(variable_dict[T], arc_tuple)
            return (true, variable_dict[T][arc_tuple])
        else
            variable_dict[T][arc_tuple] = Vector{JuMP.VariableRef}(undef, time_steps)
            return (false, variable_dict[T][arc_tuple])
        end
    end
    error("condition for reduced branch variable search not met")
end

function get_branch_argument_variable_axis(
    net_reduction_data::PNM.NetworkReductionData,
    ::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ACTransmission}
    return get_branch_argument_variable_axis(net_reduction_data, T)
end

function get_branch_argument_variable_axis(
    net_reduction_data::PNM.NetworkReductionData,
    ::Type{T},
) where {T <: PSY.ACTransmission}
    name_axis = net_reduction_data.name_to_arc_map[T]
    return collect(keys(name_axis))
end

function get_branch_argument_variable_axis(
    net_reduction_data::PNM.NetworkReductionData,
    ::Type{PowerNetworkMatrices.ThreeWindingTransformerWinding{T}},
) where {T <: PSY.ThreeWindingTransformer}
    name_axis = net_reduction_data.name_to_arc_map[T]
    return collect(keys(name_axis))
end

function get_branch_argument_constraint_axis(
    net_reduction_data::PNM.NetworkReductionData,
    reduced_branch_tracker::BranchReductionOptimizationTracker,
    ::IS.FlattenIteratorWrapper{T},
    ::Type{U},
) where {T <: PSY.ACTransmission, U <: ISOPT.ConstraintType}
    return get_branch_argument_constraint_axis(
        net_reduction_data,
        reduced_branch_tracker,
        T,
        U,
    )
end

function get_branch_argument_constraint_axis(
    net_reduction_data::PNM.NetworkReductionData,
    reduced_branch_tracker::BranchReductionOptimizationTracker,
    ::Type{T},
    ::Type{U},
) where {T <: PSY.ACTransmission, U <: ISOPT.ConstraintType}
    constraint_tracker = get_constraint_dict(reduced_branch_tracker)
    constraint_map_by_type = get_constraint_map_by_type(reduced_branch_tracker)
    name_axis = net_reduction_data.name_to_arc_map[T]
    arc_tuples_with_constraints =
        get!(constraint_tracker, U, Set{Tuple{Int, Int}}())
    constraint_map = get!(
        constraint_map_by_type,
        U,
        Dict{
            Type{<:PSY.ACTransmission},
            SortedDict{String, Tuple{Tuple{Int, Int}, String}},
        }(),
    )
    constraint_submap =
        get!(constraint_map, T, SortedDict{String, Tuple{Tuple{Int, Int}, String}}())
    for (branch_name, name_axis_tuple) in name_axis
        arc_tuple = name_axis_tuple[1]
        if !(arc_tuple in arc_tuples_with_constraints)
            constraint_submap[branch_name] = name_axis_tuple
            push!(arc_tuples_with_constraints, arc_tuple)
        end
    end
    return collect(keys(constraint_submap))
end
