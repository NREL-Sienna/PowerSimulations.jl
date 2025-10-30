# TODO - series network reduction elements are currently Vector{Any} (https://github.com/NREL-Sienna/PowerNetworkMatrices.jl/issues/189)
# When this design changes, type signatures should be updated from ::Vector{Any} throughout PSI
const NETWORK_REDUCTION_MAPS = Dict{String, String}(
    "direct_branch_map" => "reverse_direct_branch_map",
    "series_branch_map" => "reverse_series_branch_map",
    "parallel_branch_map" => "reverse_parallel_branch_map",
)

mutable struct BranchReductionOptimizationTracker
    variable_dict::Dict{
        Type{<:PSY.ACTransmission},
        Dict{Type{<:ISOPT.VariableType}, Dict},
    }
    constraint_dict::Dict{
        Type{<:PSY.ACTransmission},
        Dict{Type{<:ISOPT.ConstraintType}, Vector{String}},
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

function _search_for_reduced_branch_variable(
    tracker::BranchReductionOptimizationTracker,
    arc_tuple::Tuple{Int, Int},
    ::Type{T},
    ::Type{U},
) where {
    T <: AbstractACActivePowerFlow,
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

_get_segment_type(::T) where {T <: PSY.ACTransmission} = T
_get_segment_type(tfw_tuple::Tuple{PSY.ThreeWindingTransformer, Int}) =
    typeof(first(tfw_tuple))
_get_segment_type(x::Set) = typeof(first(x))

function get_branch_name_constraint_axis(
    all_branch_maps_by_type::Dict,
    modeled_devices::IS.FlattenIteratorWrapper{T},
    ::Type{U},
    reduction_tracker::BranchReductionOptimizationTracker,
) where {T <: PSY.ACTransmission, U <: ISOPT.ConstraintType}
    name_axis = Vector{String}()
    for (map_name, reverse_map_name) in NETWORK_REDUCTION_MAPS
        map = all_branch_maps_by_type[map_name]
        !haskey(map, T) && continue
        for entry in values(map[T])
            _add_names_to_axis!(name_axis, entry, T, U, reduction_tracker)
        end
    end
    return name_axis
end

function get_branch_argument_axis(
    network_reduction_data::PNM.NetworkReductionData,
    ::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ACTransmission}
    name_axis = network_reduction_data.name_to_arc_map[T]
    return sort!(collect(keys(name_axis)))
end

function _add_names_to_axis!(name_axis::Vector{String}, name_override::String)
    push!(name_axis, name_override)
    return
end

function _add_names_to_axis!(
    name_axis::Vector{String},
    entry::T,
    ::Type{T},
) where {T <: PSY.ACTransmission}
    push!(name_axis, PSY.get_name(entry))
    return
end

function _add_names_to_axis!(
    name_axis::Vector{String},
    entry::Set,
    ::Type{T},
) where {T <: PSY.ACTransmission}
    for branch in entry
        name = PSY.get_name(branch) * "_double_circuit"
        _add_names_to_axis!(name_axis, name)
    end
    return
end

function _add_names_to_axis!(
    name_axis::Vector{String},
    entry::Vector{Any},
    ::Type{T},
) where {T <: PSY.ACTransmission}
    for segment in entry
        # Need to check type because a series chain could have elements of different types:
        if _get_segment_type(segment) == T &&
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
) where {T <: PSY.ACTransmission, U <: ISOPT.ConstraintType}
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
) where {T <: PSY.ACTransmission, U <: ISOPT.ConstraintType}
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
) where {T <: PSY.ACTransmission, U <: ISOPT.ConstraintType}
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
) where {T <: PSY.ACTransmission, U <: ISOPT.ConstraintType}
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

function _get_branch_names(entry::T) where {T <: PSY.ACTransmission}
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
