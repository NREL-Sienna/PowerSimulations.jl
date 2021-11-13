struct StateInfo
    aux_variable_values::Dict{AuxVarKey, Any}
    variable_values::Dict{VariableKey, Any}
end

struct SimulationState
    decision_states::StateInfo
    system_state::StateInfo
end

function initialize_simulation_state(
    simulation_step::Dates.Period,
    models::SimulationModels,
)
    counts = Dict{Any, Dict}()
    for model in get_decision_models(models)
        container = get_optimization_container(model)
        model_resolution = get_resolution(model)
        value_counts = Int(simulation_step / model_resolution)
        for type in STORE_CONTAINERS
            container_counts = get!(counts, type, Dict{Any, Int}())
            field_containers = getfield(container, type)
            for (key, value) in field_containers
                # TODO: Handle case of sparse_axis_array
                # column_names =
                container_counts[key] = value_counts
            end
        end
    end
    return
end
