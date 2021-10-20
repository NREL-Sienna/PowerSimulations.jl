"""
Stores the OperationProblem definitions to be used in the simulation. When creating the
SimulationModels, the order in which the models are created determines the order on which
the simulation is executed.
"""
mutable struct SimulationModels
    decision_models::Vector{<:DecisionModel}
    emulation_model::Union{Nothing, EmulationModel}

    function SimulationModels(
        decision_models::Vector,
        emulation_model::Union{Nothing, EmulationModel} = nothing,
    )
        all_names = [get_name(x) for x in decision_models]
        emulation_model !== nothing && push!(all_names, get_name(emulation_model))
        if length(Set(all_names)) != length(decision_models) + 1
            error("All model names must be unique: $all_names")
        end

        return new(decision_models, emulation_model)
    end
end

function SimulationModels(
    decision_models::DecisionModel,
    emulation_model::Union{Nothing, EmulationModel} = nothing,
)
    return SimulationModels([decision_models], emulation_model)
end

function SimulationModels(;
    decision_models,
    emulation_model::Union{Nothing, EmulationModel} = nothing,
)
    return SimulationModels(decision_models, emulation_model)
end

# function get_decision_model(sim_models::SimulationModels, name)
#     for model in sim_models.decision_models
#         if get_name(model) == name
#             return model
#         end
#     end
#
#     error("$name is not stored")
# end

function determine_horizons!(models::SimulationModels)
    horizons = OrderedDict{Symbol, Int}()
    for model in models.decision_models
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
    for (ix, model) in enumerate(models.decision_models)
        info = SimulationInfo(ix, get_name(model), 0, false, uuid)
        set_simulation_info!(model, info)
    end
end
