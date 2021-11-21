struct StateData
    values::JuMP.Containers.DenseAxisArray{Float64}
    timestamps::Vector{Dates.DateTime}
end

get_timestamps_length(s::StateData) = length(s.timestamps)
get_data_resolution(s::StateData) = s.timestamps[2] - s.timestamps[1]
get_timestamps(s::StateData) = s.timestamps

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
    current_time::Base.RefValue{Dates.DateTime}
    end_of_step_timestamp::Base.RefValue{Dates.DateTime}
    decision_states::StateInfo
    system_state::StateInfo
end

function SimulationState()
    return SimulationState(
        Ref(UNSET_INI_TIME),
        Ref(UNSET_INI_TIME),
        StateInfo(),
        StateInfo(),
    )
end

get_end_of_step_timestamp(s::SimulationState) = s.end_of_step_timestamp[]
get_current_time(s::SimulationState) = s.current_time[]

function set_end_of_step_timestamp!(s::SimulationState, val::Dates.DateTime)
    s.end_of_step_timestamp[] = val
    return
end

function set_current_time!(s::SimulationState, val::Dates.DateTime)
    s.current_time[] = val
    return
end

get_decision_states(s::SimulationState) = s.decision_states
get_system_state(s::SimulationState) = s.system_state

function _get_state_params(models::SimulationModels, simulation_step::Dates.Period)
    params = OrderedDict{OptimizationContainerKey, NTuple{2, Dates.Millisecond}}()
    for model in get_decision_models(models)
        container = get_optimization_container(model)
        model_resolution = get_resolution(model)
        horizon_step = get_horizon(model) * model_resolution
        for type in [:variables, :aux_variables]
            field_containers = getfield(container, type)
            for key in keys(field_containers)
                if !haskey(params, key)
                    params[key] = (max(simulation_step, horizon_step), model_resolution)
                else
                    params[key] = (
                        max(params[key][1], horizon_step),
                        min(params[key][2], model_resolution),
                    )
                end
            end
        end
    end
    return params
end

function _initialize_model_states!(
    states::StateInfo,
    model::OperationModel,
    simulation_initial_time::Dates.DateTime,
    params,
)
    container = get_optimization_container(model)
    for field in [:variables, :aux_variables]
        field_containers = getfield(container, field)
        field_states = getfield(states, field)
        for (key, value) in field_containers
            # TODO: Handle case of sparse_axis_array
            value_counts = params[key][1] ÷ params[key][2]
            if length(axes(value)) == 1
                column_names = [string(encode_key(key))]
            elseif length(axes(value)) == 2
                column_names, _ = axes(value)
            else
                @warn("Multidimensional Array caching is not currently supported")
                continue
            end
            if !haskey(field_states, key) ||
               get_timestamps_length(field_states[key]) < value_counts
                field_states[key] = StateData(
                    JuMP.Containers.DenseAxisArray{Float64}(
                        undef,
                        column_names,
                        1:value_counts,
                    ),
                    collect(
                        range(
                            simulation_initial_time,
                            step = params[key][2],
                            length = value_counts,
                        ),
                    ),
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
    simulation_initial_time::Dates.DateTime,
)
    decision_states = get_decision_states(sim_state)
    params = _get_state_params(models, simulation_step)
    min_resolution = simulation_step
    for model in get_decision_models(models)
        _initialize_model_states!(decision_states, model, simulation_initial_time, params)
    end

    min_resolution = minimum([v[2] for v in values(params)])
    set_end_of_step_timestamp!(
        sim_state,
        simulation_initial_time + simulation_step - min_resolution,
    )

    em = get_emulation_model(models)
    if em !== nothing
        emulator_states = get_system_state(sim_state)
        _initialize_model_states!(emulator_states, model, simulation_step)
    end
    return
end

function update_state_data!(
    state_data::StateData,
    store_data::JuMP.Containers.DenseAxisArray{Float64},
    simulation_time::Dates.DateTime,
    model_params::ModelStoreParams,
    end_of_step_timestamp::Dates.DateTime,
)
    model_resolution = get_resolution(model_params)
    resolution_ratio = model_resolution ÷ get_data_resolution(state_data)
    @assert_op resolution_ratio >= 1

    if simulation_time > end_of_step_timestamp
        state_data_index = 1
    else
        # This seems to be a bug in indexin that requires an array when the types are Dates.DateTime
        state_data_index = indexin([simulation_time], get_timestamps(state_data))[1]
    end

    offset = resolution_ratio - 1

    # TODO: Not most optimal way to search. Most be improved before merging to master
    names, result_time_index = axes(store_data)
    state_names, _ = axes(state_data.values)

    # This implementation can fail if the names aren't in the same order. This protects for this
    @assert_op state_names == names

    for t in result_time_index
        state_range = state_data_index:(state_data_index + offset)
        for j in eachindex(names)
            for i in state_range
                state_data.values.data[j, i] = store_data.data[j, t]
            end
        end
        state_data_index += resolution_ratio
    end
    return
end
