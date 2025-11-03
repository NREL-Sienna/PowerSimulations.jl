mutable struct BranchReductionOptimizationTracker
    variable_dict::Dict{
        Type{<:PSY.ACTransmission},
        Dict{Type{<:ISOPT.VariableType}, Dict{Tuple{Int, Int}, Vector{JuMP.VariableRef}}},
    }
    constraint_dict::Dict{
        Type{<:PSY.ACTransmission},
        Dict{Type{<:ISOPT.ConstraintType}, Dict{Tuple{Int, Int}, Vector{String}}},
    }
    number_of_steps::Int
end

get_variable_dict(reduction_tracker::BranchReductionOptimizationTracker) =
    reduction_tracker.variable_dict
get_constraint_dict(reduction_tracker::BranchReductionOptimizationTracker) =
    reduction_tracker.constraint_dict
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
    return BranchReductionOptimizationTracker(Dict(), Dict(), 0)
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
    ::Type{U},
) where {
    T <: VariableType,
    U <: PSY.ACTransmission}
    time_steps = get_number_of_steps(tracker)
    if haskey(tracker.variable_dict, U)
        type_tracker = tracker.variable_dict[U]
        if haskey(type_tracker, T)
            if haskey(type_tracker[T], arc_tuple)
                return (true, type_tracker[T][arc_tuple])
            else
                type_tracker[T][arc_tuple] = Vector{JuMP.VariableRef}(undef, time_steps)
                return (false, type_tracker[T][arc_tuple])
            end
        else
            type_tracker[T] = _make_empty_tracker_dict(arc_tuple, time_steps)
            return (false, type_tracker[T][arc_tuple])
        end
    else
        tracker.variable_dict[U] = Dict{T, Dict}()
        tracker.variable_dict[U][T] = _make_empty_tracker_dict(arc_tuple, time_steps)
        return (false, tracker.variable_dict[U][T][arc_tuple])
    end
    error("condition for reduced branch variable search not met")
end

function get_branch_argument_axis(
    network_reduction_data::PNM.NetworkReductionData,
    ::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ACTransmission}
    return get_branch_argument_axis(network_reduction_data, T)
end

function get_branch_argument_axis(
    network_reduction_data::PNM.NetworkReductionData,
    ::Type{T},
) where {T <: PSY.ACTransmission}
    name_axis = network_reduction_data.name_to_arc_map[T]
    return sort!(collect(keys(name_axis)))
end

function search_for_reduced_branch_constraint!(
    tracker::BranchReductionOptimizationTracker,
    arc_tuple::Tuple{Int, Int},
    ::Type{T},
    ::Type{U},
    name::String,
) where {
    T <: ConstraintType,
    U <: PSY.ACTransmission}
    time_steps = get_number_of_steps(tracker)
    if haskey(tracker.constraint_dict, U)
        type_tracker = tracker.constraint_dict[U]
        if haskey(type_tracker, T)
            if haskey(type_tracker[T], arc_tuple)
                return true
            else
                type_tracker[T][arc_tuple] = push!(Vector{String}(), name)
                return false
            end
        else
            type_tracker[T] = Dict{Tuple{Int, Int}, Vector{String}}(
                arc_tuple => push!(Vector{String}(), name),
            )
            return false
        end
    else
        tracker.constraint_dict[U] = Dict{T, Dict}()
        tracker.constraint_dict[U][T] = Dict{Tuple{Int, Int}, Vector{String}}(
            arc_tuple => push!(Vector{String}(), name),
        )
        return false
    end
    error("condition for reduced branch variable search not met")
end
