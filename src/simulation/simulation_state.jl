struct SimulationState
    current_time::Base.RefValue{Dates.DateTime}
    last_decision_model::Base.RefValue{Symbol}
    decision_states::DatasetContainer{DataFrameDataset}
    system_states::DatasetContainer{DataFrameDataset}
end

function SimulationState()
    return SimulationState(
        Ref(UNSET_INI_TIME),
        Ref(:None),
        DatasetContainer{DataFrameDataset}(),
        DatasetContainer{DataFrameDataset}(),
    )
end

get_current_time(s::SimulationState) = s.current_time[]
get_last_decision_model(s::SimulationState) = s.last_decision_model[]
get_decision_states(s::SimulationState) = s.decision_states
get_system_states(s::SimulationState) = s.system_states

# Not to be used in hot loops
function get_system_states_resolution(s::SimulationState)
    system_state = get_system_states(s)
    # All the system states have the same resolution
    return get_data_resolution(first(values(system_state.variables)))
end

function set_current_time!(s::SimulationState, val::Dates.DateTime)
    s.current_time[] = val
    return
end

function set_last_decision_model!(s::SimulationState, val::Symbol)
    s.last_decision_model[] = val
    return
end

const STATE_TIME_PARAMS = NamedTuple{(:horizon, :resolution), NTuple{2, Dates.Millisecond}}

function _get_state_params(models::SimulationModels, simulation_step::Dates.Millisecond)
    params = OrderedDict{OptimizationContainerKey, STATE_TIME_PARAMS}()
    for model in get_decision_models(models)
        container = get_optimization_container(model)
        model_resolution = get_resolution(model)
        model_interval = get_interval(model)
        horizon_length = get_horizon(model) * model_resolution
        # This is the portion of the Horizon that "overflows" into the next step
        time_residual = horizon_length - model_interval
        @assert_op time_residual >= zero(Dates.Millisecond)
        num_runs = simulation_step / model_interval
        total_time = (num_runs - 1) * model_interval + horizon_length
        for type in fieldnames(DatasetContainer)
            field_containers = getfield(container, type)
            for key in keys(field_containers)
                !should_write_resulting_value(key) && continue
                if !haskey(params, key)
                    params[key] = (
                        horizon=max(simulation_step + time_residual, total_time),
                        resolution=model_resolution,
                    )
                else
                    params[key] = (
                        horizon=max(params[key].horizon, total_time),
                        resolution=min(params[key].resolution, model_resolution),
                    )
                end
                @debug get_name(model) key params[key]
            end
        end
    end
    return params
end

function _initialize_model_states!(
    sim_state::SimulationState,
    model::OperationModel,
    simulation_initial_time::Dates.DateTime,
    simulation_step::Dates.Millisecond,
    params::OrderedDict{OptimizationContainerKey, STATE_TIME_PARAMS},
)
    states = get_decision_states(sim_state)
    container = get_optimization_container(model)
    for field in fieldnames(DatasetContainer)
        field_containers = getfield(container, field)
        field_states = getfield(states, field)
        for (key, value) in field_containers
            !should_write_resulting_value(key) && continue
            value_counts = params[key].horizon ÷ params[key].resolution
            column_names = get_column_names(key, value)
            if !haskey(field_states, key) || length(field_states[key]) < value_counts
                field_states[key] = DataFrameDataset(
                    DataFrames.DataFrame(
                        fill(NaN, value_counts, length(column_names)),
                        column_names,
                    ),
                    collect(
                        range(
                            simulation_initial_time,
                            step=params[key].resolution,
                            length=value_counts,
                        ),
                    ),
                    params[key].resolution,
                    Int(simulation_step / params[key].resolution),
                )
            end
        end
    end
    return
end

function _initialize_system_states!(
    sim_state::SimulationState,
    ::Nothing,
    simulation_initial_time::Dates.DateTime,
    params::OrderedDict{OptimizationContainerKey, STATE_TIME_PARAMS},
)
    decision_states = get_decision_states(sim_state)
    emulator_states = get_system_states(sim_state)
    min_res = minimum([v.resolution for v in values(params)])
    for key in get_dataset_keys(decision_states)
        cols = get_column_names(key, get_dataset(decision_states, key))
        set_dataset!(
            emulator_states,
            key,
            make_system_state(
                DataFrames.DataFrame(cols .=> NaN),
                simulation_initial_time,
                min_res,
            ),
        )
    end
    return
end

function _initialize_system_states!(
    sim_state::SimulationState,
    emulation_model::EmulationModel,
    simulation_initial_time::Dates.DateTime,
    params::OrderedDict{OptimizationContainerKey, STATE_TIME_PARAMS},
)
    decision_states = get_decision_states(sim_state)
    emulator_states = get_system_states(sim_state)
    emulation_container = get_optimization_container(emulation_model)

    for field in fieldnames(DatasetContainer)
        field_containers = getfield(emulation_container, field)
        for (key, value) in field_containers
            !should_write_resulting_value(key) && continue
            column_names = get_column_names(key, value)
            set_dataset!(
                emulator_states,
                key,
                make_system_state(
                    DataFrames.DataFrame(column_names .=> NaN),
                    simulation_initial_time,
                    get_resolution(emulation_model),
                ),
            )
        end
    end

    for key in get_dataset_keys(decision_states)
        if has_dataset(emulator_states, key)
            dm_cols = get_column_names(key, get_dataset(decision_states, key))
            em_cols = get_column_names(key, get_dataset(emulator_states, key))
            @assert_op dm_cols == em_cols
            continue
        end
        cols = get_column_names(key, get_dataset(decision_states, key))
        set_dataset!(
            emulator_states,
            key,
            make_system_state(
                DataFrames.DataFrame(cols .=> NaN),
                simulation_initial_time,
                get_resolution(emulation_model),
            ),
        )
    end
    return
end

function initialize_simulation_state!(
    sim_state::SimulationState,
    models::SimulationModels,
    simulation_step::Dates.Millisecond,
    simulation_initial_time::Dates.DateTime,
)
    params = _get_state_params(models, simulation_step)
    for model in get_decision_models(models)
        _initialize_model_states!(
            sim_state,
            model,
            simulation_initial_time,
            simulation_step,
            params,
        )
    end
    set_last_decision_model!(sim_state, get_name(last(get_decision_models(models))))
    em = get_emulation_model(models)
    _initialize_system_states!(sim_state, em, simulation_initial_time, params)
    return
end

function update_decision_state!(
    state::SimulationState,
    key::OptimizationContainerKey,
    store_data::DataFrames.DataFrame,
    simulation_time::Dates.DateTime,
    model_params::ModelStoreParams,
)
    state_data = get_decision_state_data(state, key)
    model_resolution = get_resolution(model_params)
    state_resolution = get_data_resolution(state_data)
    resolution_ratio = model_resolution ÷ state_resolution
    state_timestamps = state_data.timestamps
    @assert_op resolution_ratio >= 1

    if simulation_time > get_end_of_step_timestamp(state_data)
        state_data_index = 1
        state_data.timestamps[:] .=
            range(simulation_time, step=state_resolution, length=length(state_data))
    else
        state_data_index = find_timestamp_index(state_timestamps, simulation_time)
    end

    offset = resolution_ratio - 1
    result_time_index = axes(store_data)[1]
    set_update_timestamp!(state_data, simulation_time)
    for t in result_time_index
        state_range = state_data_index:(state_data_index + offset)
        for name in DataFrames.names(store_data), i in state_range
            # TODO: We could also interpolate here
            state_data.values[i, name] = store_data[t, name]
        end
        set_last_recorded_row!(state_data, state_range[end])
        state_data_index += resolution_ratio
    end
    return
end

function update_decision_state!(
    state::SimulationState,
    key::AuxVarKey{EnergyOutput, T},
    store_data::DataFrames.DataFrame,
    simulation_time::Dates.DateTime,
    model_params::ModelStoreParams,
) where {T <: PSY.Component}
    state_data = get_decision_state_data(state, key)
    model_resolution = get_resolution(model_params)
    state_resolution = get_data_resolution(state_data)
    resolution_ratio = model_resolution ÷ state_resolution
    state_timestamps = state_data.timestamps
    @assert_op resolution_ratio >= 1

    if simulation_time > get_end_of_step_timestamp(state_data)
        state_data_index = 1
        state_data.timestamps[:] .=
            range(simulation_time, step=state_resolution, length=length(state_data))
    else
        state_data_index = find_timestamp_index(state_timestamps, simulation_time)
    end

    offset = resolution_ratio - 1
    result_time_index = axes(store_data)[1]
    set_update_timestamp!(state_data, simulation_time)
    for t in result_time_index
        state_range = state_data_index:(state_data_index + offset)
        for name in DataFrames.names(store_data), i in state_range
            state_data.values[i, name] = store_data[t, name] / resolution_ratio
        end
        set_last_recorded_row!(state_data, state_range[end])
        state_data_index += resolution_ratio
    end

    return
end

function update_decision_state!(
    state::SimulationState,
    key::AuxVarKey{S, T},
    store_data::DataFrames.DataFrame,
    simulation_time::Dates.DateTime,
    model_params::ModelStoreParams,
) where {T <: PSY.Component, S <: Union{TimeDurationOff, TimeDurationOn}}
    state_data = get_decision_state_data(state, key)
    model_resolution = get_resolution(model_params)
    state_resolution = get_data_resolution(state_data)
    resolution_ratio = model_resolution ÷ state_resolution
    @assert_op resolution_ratio >= 1

    if simulation_time > get_end_of_step_timestamp(state_data)
        state_data_index = 1
        state_data.timestamps[:] .=
            range(simulation_time, step=state_resolution, length=length(state_data))
    else
        state_data_index = find_timestamp_index(state_data.timestamps, simulation_time)
    end

    offset = resolution_ratio - 1
    result_time_index = axes(store_data)[1]
    set_update_timestamp!(state_data, simulation_time)

    if resolution_ratio == 1.0
        increment_per_period = 1.0
    elseif state_resolution < Dates.Hour(1) && state_resolution > Dates.Minute(1)
        increment_per_period = Dates.value(Dates.Minute(state_resolution))
    else
        error("Incorrect Problem Resolution specification")
    end

    for t in result_time_index
        state_range = state_data_index:(state_data_index + offset)
        @assert_op state_range[end] <= length(state_data)
        for name in DataFrames.names(store_data), i in state_range
            if t == 1 && i == 1
                if store_data[t, name] > 1
                    # Account for the fact that previous model stores the state at the end of the hour/period
                    # we take look one timestep back. As all models save Duration data based on its resolution/timesteps
                    # The 2nd terms scales the data to the state resolution.
                    state_data.values[i, name] =
                        (store_data[t, name] - 1.0) * resolution_ratio
                else
                    state_data.values[i, name] = store_data[t, name] * resolution_ratio
                end
            else
                state_data.values[i, name] =
                    store_data[t, name] > 0 ?
                    state_data.values[i - 1, name] + increment_per_period : 0
            end
        end
        set_last_recorded_row!(state_data, state_range[end])
        state_data_index += resolution_ratio
    end

    return
end

function get_decision_state_data(state::SimulationState, key::OptimizationContainerKey)
    return get_dataset(get_decision_states(state), key)
end

function get_decision_state_value(state::SimulationState, key::OptimizationContainerKey)
    return get_dataset_values(get_decision_states(state), key)
end

function get_decision_state_value(
    state::SimulationState,
    key::OptimizationContainerKey,
    date::Dates.DateTime,
)
    return get_dataset_values(get_decision_states(state), key, date)
end

function get_system_state_data(state::SimulationState, key::OptimizationContainerKey)
    return get_dataset(get_system_states(state), key)
end

function get_system_state_value(state::SimulationState, key::OptimizationContainerKey)
    return get_dataset_values(get_system_states(state), key)[1, :]
end

function update_system_state!(
    state::DatasetContainer{DataFrameDataset},
    key::OptimizationContainerKey,
    store::SimulationStore,
    model_name::Symbol,
    simulation_time::Dates.DateTime,
)
    em_data = get_em_data(store)
    ix = get_last_recorded_row(em_data, key)
    res = read_result(DataFrames.DataFrame, store, model_name, key, ix)
    dataset = get_dataset(state, key)
    set_update_timestamp!(dataset, simulation_time)
    set_dataset_values!(state, key, 1, res)
    set_last_recorded_row!(dataset, 1)
    return
end

function update_system_state!(
    state::DatasetContainer{DataFrameDataset},
    key::OptimizationContainerKey,
    decision_state::DatasetContainer{DataFrameDataset},
    simulation_time::Dates.DateTime,
)
    decision_dataset = get_dataset(decision_state, key)
    # Gets the timestamp of the value used for the update, which might not match exactly the
    # simulation time since the value might have not been updated yet
    ts = get_value_timestamp(decision_dataset, simulation_time)
    system_dataset = get_dataset(state, key)
    get_update_timestamp(system_dataset)
    if ts == get_update_timestamp(system_dataset)
        # Uncomment for debugging
        #@warn "Skipped overwriting data with the same timestamp \\
        #       key: $(encode_key_as_string(key)), $(simulation_time), $ts"
        return
    end

    if get_update_timestamp(system_dataset) > ts
        error("Trying to update with past data a future state timestamp \\
            key: $(encode_key_as_string(key)), $(simulation_time), $ts")
    end

    # Writes the timestamp of the value used for the update
    set_update_timestamp!(system_dataset, ts)
    # Keep coordination between fields. System state is an array of size 1
    system_dataset.timestamps[1] = ts
    set_dataset_values!(state, key, 1, get_dataset_value(decision_dataset, simulation_time))
    # This value shouldn't be other than one and after one execution is no-op.
    set_last_recorded_row!(system_dataset, 1)
    return
end

function get_system_state_value(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    return get_system_state_value(state, VariableKey(T, U))
end

function get_system_state_value(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return get_system_state_value(state, AuxVarKey(T, U))
end

function get_system_state_value(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return get_system_state_value(state, ConstraintKey(T, U))
end

function get_system_state_data(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    return get_system_state_data(state, VariableKey(T, U))
end

function get_system_state_data(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return get_system_state_data(state, AuxVarKey(T, U))
end

function get_system_state_data(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return get_system_state_data(state, ConstraintKey(T, U))
end
