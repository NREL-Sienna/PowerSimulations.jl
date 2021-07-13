"""
Stores the OperationProblem definitions to be used in the simulation. When creating the
SimulationProblems, the order in which the problems are created determines the order on which
the simulation is executed.
"""
mutable struct SimulationProblems
    models::OrderedDict{Symbol, DecisionModel}
    names::Vector{Symbol}
    function SimulationProblems(; kwargs...)
        prob_dict = OrderedDict(kwargs...)
        new(prob_dict, collect(keys(prob_dict)))
    end
end

Base.getindex(problems::SimulationProblems, key::Symbol) = problems.models[key]
Base.getindex(problems::SimulationProblems, key) = getindex(problems, Symbol(key))

Base.length(problems::SimulationProblems) = length(problems.models)
Base.first(problems::SimulationProblems) = first(problems.models)
Base.iterate(problems::SimulationProblems, args...) = iterate(problems.models, args...)

get_problem_names(problems::SimulationProblems) = problems.names

function get_problem_number(problems::SimulationProblems, name)
    return findfirst(x -> x == Symbol(name), get_problem_names(problems))
end

function determine_horizons!(problems::SimulationProblems)
    horizons = OrderedDict{Symbol, Int}()
    for (name, model) in problems.models
        container = get_optimization_container(model)
        settings = get_settings(container)
        horizon = get_horizon(settings)
        if horizon == UNSET_HORIZON
            sys = get_system(model)
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
    for (ix, (name, model)) in enumerate(problems.models)
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
        set_simulation_info!(model, info)
    end
end
