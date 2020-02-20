"""
    _calculate_interval_inner_counts(order::Dict{Int,String},
                                          intervals::Dict{String,<:Dates.TimePeriod},
                                          step_resolution::Dates.TimePeriod)

Calculates how many times a stage is executed for every interval of the previous stage
"""
function _calculate_interval_inner_counts(
    order::Dict{Int, String},
    intervals::Dict{String, Tuple{Dates.TimePeriod, <:FeedForwardChronology}},
    step_resolution::Dates.TimePeriod,
)
    reverse_order = sort(collect(keys(order)), rev = true)
    interval_run_counts = Dict{Int, Int}()
    for k in reverse_order[1:(end - 1)]
        stage_name = order[k]
        previous_stage_name = order[k - 1]
        stage_interval = intervals[stage_name][1]
        previous_stage_interval = intervals[previous_stage_name][1]
        if Dates.Millisecond(previous_stage_interval % stage_interval) !=
           Dates.Millisecond(0)
            throw(IS.ConflictingInputsError("The interval configuration provided results in a fractional number of executions of stage $stage_name"))
        end
        interval_run_counts[k] = previous_stage_interval / stage_interval
        @debug "Stage $k is executed $(interval_run_counts[k]) time within each interval of Stage $(k-1)"
    end
    stage_name = order[1]
    stage_interval = intervals[stage_name][1]
    interval_run_counts[1] = 1
    return interval_run_counts
end

""" Function calculates the total number of stage executions in the simulation and allocates the appropiate vector"""
function _allocate_execution_order(interval_run_counts::Dict{Int, Int})
    total_size_of_vector = 0
    for (k, counts) in interval_run_counts
        mult = 1
        for i in 1:k
            mult *= interval_run_counts[i]
        end
        total_size_of_vector += mult
    end
    return -1 * ones(Int, total_size_of_vector)
end

function _fill_execution_order(
    execution_order::Vector{Int},
    interval_run_counts::Dict{Int, Int},
)
    function _fill_stage(index::Int, stage::Int)
        if stage < last_stage
            next_stage = stage + 1
            for i in 1:interval_run_counts[next_stage]
                index = _fill_stage(index, next_stage)
            end
        end
        execution_order[index] = stage
        index -= 1
    end

    index = length(execution_order)
    stages = sort!(collect(keys(interval_run_counts)))
    last_stage = stages[end]
    _fill_stage(index, stages[1])
    return
end

function _get_execution_order_vector(
    order::Dict{Int, String},
    intervals::Dict{String, Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}},
    step_resolution::Dates.TimePeriod,
)
    length(order) == 1 && return [1]
    interval_run_counts =
        _calculate_interval_inner_counts(order, intervals, step_resolution)
    execution_order_vector = _allocate_execution_order(interval_run_counts)
    _fill_execution_order(execution_order_vector, interval_run_counts)
    @assert isempty(findall(x -> x == -1, execution_order_vector))
    return execution_order_vector
end

function _check_stage_order(order::Dict{Int, String})
    length(order) == 1 && return
    if !mapreduce(x -> x == 1, *, diff(sort!(collect(keys(order)))))
        throw(IS.InvalidValue("Keys in the order dictionary aren't specified as consecutive integrers 1 -> N"))
    end
    return
end

function _check_all_inputs_present(
    order::Dict{Int, String},
    intervals::Dict{String, <:Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}},
    horizons::Dict{String, Int},
)
    for stage_name in values(order)
        if !(stage_name in keys(horizons))
            throw(IS.ConflictingInputsError("Horizon not defined for stage $(stage_name)"))
        end
        if !(stage_name in keys(intervals))
            throw(IS.ConflictingInputsError("Interval not defined for stage $(stage_name)"))
        end
    end
    return
end

function _check_feedforward(
    feedforward::Dict{Tuple{String, Symbol, Symbol}, <:AbstractAffectFeedForward},
    feedforward_chronologies::Dict{Pair{String, String}, <:FeedForwardChronology},
)
    isempty(feedforward) && return
    for stage_key in keys(feedforward)
        @debug stage_key
        if !mapreduce(x -> x.second == stage_key[1], |, keys(feedforward_chronologies))
            throw(ArgumentError("No valid Chronology has been defined for the feedforward added to $(stage_key[1])"))
        end
    end
    return
end

function _check_chronology_consistency(
    order::Dict{Int, String},
    feedforward_chronologies::Dict{Pair{String, String}, <:FeedForwardChronology},
    ini_cond_chronology::InitialConditionChronology,
)

    if isempty(feedforward_chronologies)
        @warn("No Feedforward Chronologies have been defined. This configuration assummes that there is no information passing between stages")
    end
    if length(order) == 1
        if isa(ini_cond_chronology, InterStageChronology)
            @warn("Single stage detected, the default Initial Condition Chronology is IntraStageChronology(), other values will be ignored.")
        end
    end
    #TODO: Add more consistency checks
    return
end
# TODO: Add DocString
@doc raw"""
    SimulationSequence(initial_time::Union{Dates.DateTime, Nothing}
                        horizons::Dict{String, Int}
                        intervals::Dict{String, <:Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}}
                        order::Dict{Int, String}
                        feedforward_chronologies::Dict{Pair{String, String}, <:FeedForwardChronology}
                        feedforward::Dict{Tuple{String, Symbol, Symbol}, <:AbstractAffectFeedForward}
                        ini_cond_chronology::Dict{String, <:FeedForwardChronology}
                        cache::Dict{String, Vector{<:AbstractCache}}
                        )
"""
mutable struct SimulationSequence
    horizons::Dict{String, Int}
    step_resolution::Dates.TimePeriod
    # The string here is the name of the stage
    intervals::Dict{String, Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}}
    order::Dict{Int, String}
    feedforward_chronologies::Dict{Pair{String, String}, <:FeedForwardChronology}
    feedforward::Dict{Tuple{String, Symbol, Symbol}, <:AbstractAffectFeedForward}
    ini_cond_chronology::InitialConditionChronology
    cache::Dict{String, Vector{<:AbstractCache}}
    execution_order::Vector{Int}
    current_execution_index::Int64

    function SimulationSequence(;
        horizons::Dict{String, Int},
        step_resolution::Dates.TimePeriod,
        intervals::Dict{String, <:Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}},
        order::Dict{Int, String},
        feedforward_chronologies = Dict{Pair{String, String}, FeedForwardChronology}(),
        feedforward = Dict{Tuple{String, Symbol, Symbol}, AbstractAffectFeedForward}(),
        ini_cond_chronology = InterStageChronology(),
        cache = Dict{String, Vector{AbstractCache}}(),
    )
        _check_stage_order(order)
        _check_all_inputs_present(order, intervals, horizons)
        _intervals = Dict{String, Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}}()
        for (k, v) in intervals
            _intervals[k] = (IS.time_period_conversion(intervals[k][1]), intervals[k][2])
        end
        step_resolution = IS.time_period_conversion(step_resolution)
        _check_feedforward(feedforward, feedforward_chronologies)
        _check_chronology_consistency(order, feedforward_chronologies, ini_cond_chronology)
        if length(order) == 1
            ini_cond_chronology = IntraStageChronology()
        end
        new(
            horizons,
            step_resolution,
            _intervals,
            order,
            feedforward_chronologies,
            feedforward,
            ini_cond_chronology,
            cache,
            _get_execution_order_vector(order, _intervals, step_resolution),
            0,
        )

    end
end

get_stage_horizon(s::SimulationSequence, stage::String) = get(s.horizons, stage, nothing)
get_stage_interval(s::SimulationSequence, stage::String) = s.intervals[stage][1]
get_stage_name(s::SimulationSequence, stage::Stage) =
    get(s.order, get_number(stage), nothing)
get_step_resolution(s::SimulationSequence) = s.step_resolution
function get_stage_interval_chronology(s::SimulationSequence, stage::String)
    return s.intervals[stage][2]
end
