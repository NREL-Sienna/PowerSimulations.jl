"""
Stores the OperationProblem definitions to be used in the simulation. When creating the
SimulationProblems, the order in which the problems are created determines the order on which
the simulation is executed.
"""
mutable struct SimulationProblems
    op_problems::OrderedDict{Symbol, OperationsProblem}
    function SimulationProblems(; kwargs...)
        new(OrderedDict(kwargs...))
    end
end

Base.getindex(problems::SimulationProblems, key::Symbol) = problems.op_problems[key]
Base.getindex(problems::SimulationProblems, key) = getindex(problems, Symbol(key))

Base.length(problems::SimulationProblems) = length(problems.op_problems)
Base.first(problems::SimulationProblems) = first(problems.op_problems)

get_problem_names(problems::SimulationProblems) = collect(keys(problems.op_problems))

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

function determine_step_resolution(problems::SimulationProblems)
    resolution = get_resolution(first(problems)[2])
    return IS.time_period_conversion(resolution)
end

function initialize_simulation_internals!(problems::SimulationProblems, uuid::Base.UUID)
    for (ix, (name, problem)) in enumerate(problems.op_problems)
        info = SimulationInfo(
            ix,
            # JDNOTES: Making conversion to avoid breaking things
            String(name),
            0,
            0,
            Set{CacheKey}(),
            0,
            Dict{Int, FeedForwardChronology}(),
            false,
            uuid
        )
        set_simulation_info(problem, info)
    end
end
