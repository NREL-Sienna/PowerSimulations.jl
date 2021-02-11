"""
Stores the OperationProblem definitions to be used in the simulation. When creating the
SimulationProblems, the order in which the problems are created determines the order on which
the simulation is executed.
"""
mutable struct SimulationProblems
    op_problems::OrderedDict{Symbol, OperationsProblem}
    names::Vector{Symbol}
    function SimulationProblems(; kwargs...)
        prob_dict = OrderedDict(kwargs...)
        new(prob_dict, collect(keys(prob_dict)))
    end
end

Base.getindex(problems::SimulationProblems, key::Symbol) = problems.op_problems[key]
Base.getindex(problems::SimulationProblems, key) = getindex(problems, Symbol(key))

Base.length(problems::SimulationProblems) = length(problems.op_problems)
Base.first(problems::SimulationProblems) = first(problems.op_problems)
Base.iterate(problems::SimulationProblems, args...) = iterate(problems.op_problems, args...)

get_problem_names(problems::SimulationProblems) = problems.names
get_problem_instances(problems::SimulationProblems) = values(problems.op_problems)

function get_problem_numer(problems::SimulationProblems, name)
    return findfirst(x -> x == Symbol(name), get_problem_names(problems))
end

function determine_horizons!(problems::SimulationProblems)
    horizons = OrderedDict{Symbol, Int}()
    for (name, problem) in problems.op_problems
        optimization_container = get_optimization_container(problem)
        settings = get_settings(optimization_container)
        horizon = get_horizon(settings)
        if horizon == UNSET_HORIZON
            sys = get_system(problem)
            horizon = PSY.get_forecast_horizon(sys)
            set_horizon!(settings, horizon)
        end
        horizons[name] = horizon
    end
    return horizons
end

function determine_step_resolution(intervals)
    return first(intervals)[2][1]
end

function initialize_simulation_internals!(problems::SimulationProblems, uuid::Base.UUID)
    for (ix, (name, problem)) in enumerate(problems.op_problems)
        info = SimulationInfo(
            ix,
            # JDNOTE: Making conversion to avoid breaking things
            String(name),
            0,
            0,
            Set{CacheKey}(),
            0,
            Dict{Int, FeedForwardChronology}(),
            false,
            uuid,
        )
        set_simulation_info!(problem, info)
        settings = get_settings(problem)
        set_use_parameters!(settings, true)
    end
end
