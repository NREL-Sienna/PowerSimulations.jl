"""
    _calculate_interval_inner_counts(order::Dict{Int,String},
                                          intervals::OrderedDict{String,<:Dates.TimePeriod},
                                          step_resolution::Dates.TimePeriod)

Calculates how many times a stage is executed for every interval of the previous stage
"""
function _calculate_interval_inner_counts(
    intervals::OrderedDict{Symbol, Tuple{Dates.TimePeriod, <:FeedForwardChronology}},
)
    order = collect(keys(intervals))
    reverse_order = length(intervals):-1:1
    interval_run_counts = Dict{Int, Int}(1 => 1)
    for k in reverse_order[1:(end - 1)]
        stage_name = order[k]
        previous_stage_name = order[k - 1]
        stage_interval = intervals[stage_name][1]
        previous_stage_interval = intervals[previous_stage_name][1]
        if Dates.Millisecond(previous_stage_interval % stage_interval) !=
           Dates.Millisecond(0)
            throw(
                IS.ConflictingInputsError(
                    "The interval configuration provided results in a fractional number of executions of stage $stage_name",
                ),
            )
        end
        interval_run_counts[k] = previous_stage_interval / stage_interval
        @debug "Stage $k is executed $(interval_run_counts[k]) time within each interval of Stage $(k-1)"
    end
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
    intervals::OrderedDict{Symbol, Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}},
)
    length(intervals) == 1 && return [1]
    interval_run_counts = _calculate_interval_inner_counts(intervals)
    execution_order_vector = _allocate_execution_order(interval_run_counts)
    _fill_execution_order(execution_order_vector, interval_run_counts)
    @assert isempty(findall(x -> x == -1, execution_order_vector))
    return execution_order_vector
end

function _check_feedforward(
    feedforward::Dict{Tuple{String, Symbol, Symbol}, <:AbstractAffectFeedForward},
    feedforward_chronologies::Dict{Pair{String, String}, <:FeedForwardChronology},
)
    isempty(feedforward) && return
    for stage_key in keys(feedforward)
        @debug stage_key
        if !mapreduce(x -> x.second == stage_key[1], |, keys(feedforward_chronologies))
            throw(
                ArgumentError(
                    "No valid Chronology has been defined for the feedforward added to $(stage_key[1])",
                ),
            )
        end
    end
    return
end

function _check_chronology_consistency(
    problems::SimulationProblems,
    feedforward_chronologies::Dict{Pair{String, String}, <:FeedForwardChronology},
    ini_cond_chronology::InitialConditionChronology,
)
    if isempty(feedforward_chronologies)
        @warn(
            "No Feedforward Chronologies have been defined. This configuration assummes that there is no information passing between stages"
        )
    end
    if length(problems) == 1
        if isa(ini_cond_chronology, InterStageChronology)
            @warn(
                "Single stage detected, the default Initial Condition Chronology is IntraStageChronology(), other values will be ignored."
            )
        end
    end
    # TODO: Add more consistency checks
    return
end

function _check_cache_definition(cache::Dict{<:Tuple, <:AbstractCache})
    for (stage_names, c) in cache
        if typeof(c) == TimeStatusChange && length(stage_names) > 1
            error(
                "TimeStatusChange cache currently only supports single stage. Please consider changing your cache definitions",
            )
        end
    end
    return
end

@doc raw"""
    SimulationSequence(horizons::Dict{String, Int}
                        step_resolution::Dates.TimePeriod
                        intervals::Dict{String, <:Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}}
                        order::Dict{Int, String}
                        feedforward_chronologies::Dict{Pair{String, String}, <:FeedForwardChronology}
                        feedforward::Dict{Tuple{String, Symbol, Symbol}, <:AbstractAffectFeedForward}
                        ini_cond_chronology::Dict{String, <:FeedForwardChronology}
                        cache::Dict{String, AbstractCache}
                        )
"""
mutable struct SimulationSequence
    horizons::OrderedDict{Symbol, Int}
    # JDNOTES: This field might be able to go away.
    step_resolution::Dates.TimePeriod
    # The string here is the name of the stage
    intervals::OrderedDict{Symbol, Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}}
    feedforward_chronologies::Dict{Pair{String, String}, <:FeedForwardChronology}
    feedforward::Dict{Tuple{String, Symbol, Symbol}, <:AbstractAffectFeedForward}
    ini_cond_chronology::InitialConditionChronology
    cache::Dict{Tuple, AbstractCache}
    execution_order::Vector{Int}
    executions_by_stage::Dict{Symbol, Int}
    current_execution_index::Int64
    uuid::Base.UUID

    function SimulationSequence(;
        problems::SimulationProblems,
        intervals::Dict{String, <:Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}},
        feedforward_chronologies = Dict{Pair{String, String}, FeedForwardChronology}(),
        feedforward = Dict{Tuple{String, Symbol, Symbol}, AbstractAffectFeedForward}(),
        ini_cond_chronology = InterStageChronology(),
        cache = Dict{Tuple, AbstractCache}(),
    )
        horizons = determine_horizons!(problems)
        _intervals = OrderedDict{Symbol, Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}}()
        for k in get_problem_names(problems)
            # JDNOTES: Temporary conversion while we re-define how to do this
            k_ = string(k)
            if !(k_ in keys(intervals))
                throw(IS.ConflictingInputsError("Interval not defined for stage $(k_)"))
            end
            _intervals[k] = (IS.time_period_conversion(intervals[k_][1]), intervals[k_][2])
        end
        step_resolution = determine_step_resolution(problems)
        _check_feedforward(feedforward, feedforward_chronologies)
        _check_chronology_consistency(problems, feedforward_chronologies, ini_cond_chronology)
        _check_cache_definition(cache)
        if length(problems) == 1
            ini_cond_chronology = IntraStageChronology()
        end
        execution_order = _get_execution_order_vector(_intervals)
        executions_by_stage = _get_num_executions_by_stage(problems, execution_order)
        sequence_uuid = IS.make_uuid()
        initialize_simulation_internals!(problems, sequence_uuid)
        new(
            horizons,
            step_resolution,
            _intervals,
            feedforward_chronologies,
            feedforward,
            ini_cond_chronology,
            cache,
            execution_order,
            executions_by_stage,
            0,
            sequence_uuid
        )
    end
end

function _get_num_executions_by_stage(problems, execution_order)
    problem_names = get_problem_names(problems)
    executions_by_stage = Dict(x => 0 for x in problem_names)
    for stage_number in execution_order
        executions_by_stage[problem_names[stage_number]] += 1
    end
    return executions_by_stage
end

function get_stage_horizon(sequence::SimulationSequence, stage::String)
    horizon = get(sequence.horizons, stage, nothing)
    if horizon === nothing
        throw(ArgumentError("Stage $(stage) not present in the simulation"))
    end
    return horizon
end

get_stage_interval(sequence::SimulationSequence, stage::String) =
    sequence.intervals[stage][1]

function get_stage_name(sequence::SimulationSequence, stage::OperationsProblem)
    name = get(get_order(sequence), get_number(stage), nothing)
    if name === nothing
        throw(ArgumentError("Stage $(stage.internal.number) not present in the simulation"))
    end
    return name
end

get_step_resolution(sequence::SimulationSequence) = sequence.step_resolution

function get_stage_interval_chronology(sequence::SimulationSequence, stage::String)
    return sequence.intervals[stage][2]
end

get_order(sequence::SimulationSequence) = sequence.order
