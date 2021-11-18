struct StateData
    values::JuMP.Containers.DenseAxisArray{Float64}
    timestamps::Vector
end

get_timestamps_length(s::StateData) = length(s.timestamps)

struct StateInfo
    duals::Dict{ConstraintKey, StateData}
    aux_variables::Dict{AuxVarKey, StateData}
    variables::Dict{VariableKey, StateData}
end

function StateInfo()
    return StateInfo(
        Dict{ConstraintKey, StateData}(),
        Dict{AuxVarKey, StateData}(),
        Dict{VariableKey, StateData}(),
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

function _get_state_params(models::SimulationModels, simulation_step::Dates.Period)
    params = Dict{Symbol, NTuple{2, Dates.Millisecond}}()
    for model in get_decision_models(models)
        model_name = get_name(model)
        model_resolution = get_resolution(model)
        horizon_step = get_horizon(model) * model_resolution
        if !haskey(params, model_name)
            params[model_name] = (max(simulation_step, horizon_step), model_resolution)
        else
            current_values = params[model_name]
            params[model_name] = (
                max(current_values[1], horizon_step),
                min(current_values[1], model_resolution),
            )
        end
    end
    return params
end

function _initialize_model_states!(
    states::StateInfo,
    model::OperationModel,
    params::NTuple{2, Dates.Millisecond},
)
    container = get_optimization_container(model)
    value_counts = params[1] ÷ params[2]
    for type in [:variables, :aux_variables]
        field_containers = getfield(container, type)
        field_states = getfield(states, type)
        for (key, value) in field_containers
            # TODO: Handle case of sparse_axis_array
            column_names, _ = axes(value)
            if !haskey(field_states, key) ||
               get_timestamps_length(field_states[key]) < value_counts
                field_states[key] = StateData(
                    JuMP.Containers.DenseAxisArray{Float64}(
                        undef,
                        column_names,
                        1:value_counts,
                    ),
                    Vector(undef, value_counts),
                )
            end
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
    params = _get_state_params(models, simulation_step)
    for model in get_decision_models(models)
        model_name = get_name(model)
        _initialize_model_states!(decision_states, model, params[model_name])
    end

    em = get_emulation_model(models)
    if em !== nothing
        emulator_states = get_system_state(sim_state)
        _initialize_model_states!(emulator_states, model, simulation_step)
    end
    return
end

function update_state_data!(
    state_data::StateData,
    data::JuMP.Containers.DenseAxisArray{Float64},
    time_steps::StepRange{Dates.DateTime, Dates.Millisecond},
)
    if get_timestamps_length(state_data) == length(time_steps)
        state_data.timestamp .= timestamps
        # This is not the most optimal way to update the data. This method will be used during development
        # Change before merging to master
    elseif get_timestamps_length(state_data) > length(time_steps)

    else
        @assert false
    end
    error()
end
