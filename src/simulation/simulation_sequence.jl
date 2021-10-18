"""
    _calculate_interval_inner_counts(order::Dict{Int,String},
                                          intervals::OrderedDict{String,<:Dates.TimePeriod},
                                          step_resolution::Dates.TimePeriod)

Calculates how many times a problem is executed for every interval of the previous problem
"""
function _calculate_interval_inner_counts(
    intervals::OrderedDict{Symbol, Tuple{Dates.TimePeriod, <:FeedforwardChronology}},
)
    order = collect(keys(intervals))
    reverse_order = length(intervals):-1:1
    interval_run_counts = Dict{Int, Int}(1 => 1)
    for k in reverse_order[1:(end - 1)]
        problem_name = order[k]
        previous_problem_name = order[k - 1]
        problem_interval = intervals[problem_name][1]
        previous_problem_interval = intervals[previous_problem_name][1]
        if Dates.Millisecond(previous_problem_interval % problem_interval) !=
           Dates.Millisecond(0)
            throw(
                IS.ConflictingInputsError(
                    "The interval configuration provided results in a fractional number of executions of problem $problem_name",
                ),
            )
        end
        interval_run_counts[k] = previous_problem_interval / problem_interval
        @debug "problem $k is executed $(interval_run_counts[k]) time within each interval of problem $(k-1)"
    end
    return interval_run_counts
end

""" Function calculates the total number of problem executions in the simulation and allocates the appropiate vector"""
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
    function _fill_problem(index::Int, problem::Int)
        if problem < last_problem
            next_problem = problem + 1
            for i in 1:interval_run_counts[next_problem]
                index = _fill_problem(index, next_problem)
            end
        end
        execution_order[index] = problem
        index -= 1
    end

    index = length(execution_order)
    problems = sort!(collect(keys(interval_run_counts)))
    last_problem = problems[end]
    _fill_problem(index, problems[1])
    return
end

function _get_execution_order_vector(
    intervals::OrderedDict{Symbol, Tuple{<:Dates.TimePeriod, <:FeedforwardChronology}},
)
    length(intervals) == 1 && return [1]
    interval_run_counts = _calculate_interval_inner_counts(intervals)
    execution_order_vector = _allocate_execution_order(interval_run_counts)
    _fill_execution_order(execution_order_vector, interval_run_counts)
    @assert isempty(findall(x -> x == -1, execution_order_vector))
    return execution_order_vector
end

function _check_feedforward(feedforward, feedforward_chronologies)
    isempty(feedforward) && return
    for problem_key in keys(feedforward)
        if problem_key ∉ [k.second for k in keys(feedforward_chronologies)]
            throw(
                ArgumentError(
                    "No valid Chronology has been defined for the feedforward added to $(problem_key)",
                ),
            )
        end
    end
    return
end

function _check_chronology_consistency(
    problems::SimulationModels,
    feedforward_chronologies,
    ini_cond_chronology::InitialConditionChronology,
)
    if isempty(feedforward_chronologies)
        @warn(
            "No Feedforward Chronologies have been defined. This configuration assummes that there is no information passing between problems"
        )
    end
    if length(problems) == 1
        if isa(ini_cond_chronology, InterProblemChronology)
            @warn(
                "Single problem detected, the default Initial Condition Chronology is IntraProblemChronology(), other values will be ignored."
            )
        end
    end
    # TODO: Add more consistency checks
    return
end

function _check_cache_definition(cache::Dict{<:Tuple, <:AbstractCache})
    for (problem_names, c) in cache
        if typeof(c) == TimeStatusChange && length(problem_names) > 1
            error(
                "TimeStatusChange cache currently only supports single problem. Please consider changing your cache definitions",
            )
        end
    end
    return
end

function _get_num_executions_by_problem(problems, execution_order)
    problem_names = get_model_names(problems)
    executions_by_problem = Dict(x => 0 for x in problem_names)
    for problem_number in execution_order
        executions_by_problem[problem_names[problem_number]] += 1
    end
    return executions_by_problem
end

@doc raw"""
    SimulationSequence(
                        models::SimulationModels,
                        feedforward::Dict{Symbol, <:AbstractAffectFeedForward}
                        ini_cond_chronology::Dict{Symbol, <:FeedForwardChronology}
                        cache::Dict{Symbol, AbstractCache}
                        )
"""
mutable struct SimulationSequence
    horizons::OrderedDict{Symbol, Int}
    intervals::OrderedDict{Symbol, Tuple{<:Dates.TimePeriod, <:FeedForwardChronology}}
    feedforwards::Dict{<:Tuple, <:AbstractAffectFeedForward}
    ini_cond_chronology::InitialConditionChronology
    execution_order::Vector{Int}
    executions_by_problem::Dict{Symbol, Int}
    current_execution_index::Int64
    uuid::Base.UUID

    function SimulationSequence(;
        models::SimulationModels,
        feedforward = Dict{Symbol, AbstractAffectFeedForward}(),
        ini_cond_chronology = InterProblemChronology(),
    )
        # Allow strings or symbols as keys; convert to symbols.
        intervals = Dict(Symbol(k) => v for (k, v) in intervals)
        if eltype(feedforward_chronologies).parameters[1] != Pair{Symbol, Symbol}
            feedforward_chronologies = Dict(
                Pair(Symbol(k.first), Symbol(k.second)) => v for
                (k, v) in feedforward_chronologies
            )
        end
        if eltype(feedforward).parameters[1] != Symbol
            feedforward = Dict(Symbol(k) => v for (k, v) in feedforward)
        end
        horizons = determine_horizons!(models)
        _intervals =
            OrderedDict{Symbol, Tuple{<:Dates.TimePeriod, <:FeedforwardChronology}}()
        for name in get_model_names(models)
            # JDNOTE: Temporary conversion while we re-define how to do this
            if !(name in keys(intervals))
                throw(IS.ConflictingInputsError("Interval not defined for problem $name"))
            end
            _intervals[name] =
                (IS.time_period_conversion(intervals[name][1]), intervals[name][2])
        end
        step_resolution = determine_step_resolution(_intervals)
        _check_feedforward(feedforward, feedforward_chronologies)
        _check_chronology_consistency(models, feedforward_chronologies, ini_cond_chronology)
        _check_cache_definition(cache)
        if length(models) == 1
            ini_cond_chronology = IntraProblemChronology()
        end
        execution_order = _get_execution_order_vector(_intervals)
        executions_by_problem = _get_num_executions_by_problem(models, execution_order)
        sequence_uuid = IS.make_uuid()
        initialize_simulation_internals!(models, sequence_uuid)
        new(
            horizons,
            step_resolution,
            _intervals,
            feedforward,
            ini_cond_chronology,
            execution_order,
            executions_by_problem,
            0,
            sequence_uuid,
        )
    end
end

get_step_resolution(sequence::SimulationSequence) = sequence.step_resolution

function get_problem_interval_chronology(sequence::SimulationSequence, problem)
    return sequence.intervals[problem][2]
end

function get_interval(sequence::SimulationSequence, problem::Symbol)
    return sequence.intervals[problem][1]
end

function get_interval(sequence::SimulationSequence, model)
    return sequence.intervals[model][1]
end

get_execution_order(sequence::SimulationSequence) = sequence.execution_order
