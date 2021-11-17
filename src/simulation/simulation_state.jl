struct StateInfo
    # TODO: enable passing constraint duals as states
    aux_variables::Dict{AuxVarKey, JuMP.Containers.DenseAxisArray{Float64}}
    variables::Dict{VariableKey, JuMP.Containers.DenseAxisArray{Float64}}
end

function StateInfo()
    return StateInfo(
        Dict{AuxVarKey, JuMP.Containers.DenseAxisArray{Float64}}(),
        Dict{VariableKey, JuMP.Containers.DenseAxisArray{Float64}}(),
    )
end

struct SimulationState
    decision_states::StateInfo
    system_state::StateInfo
end

function SimulationState()
    return SimulationState(StateInfo(), StateInfo())
end

get_decision_states(s::SimulationState) = s.decision_states
get_system_state(s::SimulationState) = s.system_state

function _initialize_model_states!(
    states::StateInfo,
    model::OperationModel,
    simulation_step::Dates.Period,
)
    container = get_optimization_container(model)
    model_resolution = get_resolution(model)
    value_counts = simulation_step ÷ model_resolution
    for type in [:variables, :aux_variables]
        field_containers = getfield(container, type)
        field_states = getfield(states, type)
        for (key, value) in field_containers
            # TODO: Handle case of sparse_axis_array
            column_names, _ = axes(value)
            field_states[key] =
                JuMP.Containers.DenseAxisArray{Float64}(undef, column_names, 1:value_counts)
        end
    end
    return
end

function initialize_simulation_state!(
    sim_state::SimulationState,
    models::SimulationModels,
    simulation_step::Dates.Period,
)
    decision_states = get_decision_states(sim_state)
    emulator_states = get_system_state(sim_state)
    for model in get_decision_models(models)
        _initialize_model_states!(decision_states, model, simulation_step)
    end
    em = get_emulation_model(models)
    if em !== nothing
        _initialize_model_states!(emulator_states, model, simulation_step)
    end
    return
end
