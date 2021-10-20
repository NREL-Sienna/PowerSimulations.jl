"""
Stores the OperationProblem definitions to be used in the simulation. When creating the
SimulationModels, the order in which the models are created determines the order on which
the simulation is executed.
"""
mutable struct SimulationModels
    models::Vector{DecisionModel}

    function SimulationModels(models)
        all_names = [get_name(x) for x in models]
        if length(Set(all_names)) != length(models)
            error("All model names must be unique: $all_names")
        end

        return new(models)
    end
end

function SimulationModels(args...)
    return SimulationModels(collect(args))
end

Base.length(x::SimulationModels) = length(x.models)
Base.first(x::SimulationModels) = first(x.models)
Base.getindex(x::SimulationModels, index) = x.models[index]
Base.iterate(x::SimulationModels, args...) = iterate(x.models, args...)

function get_model(sim_models::SimulationModels, name)
    for model in sim_models
        if get_name(model) == name
            return model
        end
    end

    error("$name is not stored")
end

get_model_names(x::SimulationModels) = [y.name for y in x.models]

function get_model_number(models::SimulationModels, name)
    return findfirst(x -> x == name, get_model_names(models))
end

function determine_horizons!(models::SimulationModels)
    horizons = OrderedDict{Symbol, Int}()
    for model in models
        container = get_optimization_container(model)
        settings = get_settings(container)
        horizon = get_horizon(settings)
        if horizon == UNSET_HORIZON
            sys = get_system(model)
            horizon = PSY.get_forecast_horizon(sys)
            set_horizon!(settings, horizon)
        end
        horizons[get_name(model)] = horizon
    end
    return horizons
end

function determine_step_resolution(intervals)
    return first(intervals)[2][1]
end

function initialize_simulation_internals!(models::SimulationModels, uuid::Base.UUID)
    for (ix, model) in enumerate(models)
        info = SimulationInfo(
            ix,
            # JDNOTE: Making conversion to avoid breaking things
            get_name(model),
            0,
            0,
            Set{CacheKey}(),
            0,
            Dict{Int, FeedforwardChronology}(),
            false,
            uuid,
        )
        set_simulation_info!(model, info)
    end
end
