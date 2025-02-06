struct SimulationState
    current_time::Base.RefValue{Dates.DateTime}
    last_decision_model::Base.RefValue{Symbol}
    decision_states::DatasetContainer{InMemoryDataset}
    system_states::DatasetContainer{InMemoryDataset}
end

function SimulationState()
    return SimulationState(
        Ref(UNSET_INI_TIME),
        Ref(:None),
        DatasetContainer{InMemoryDataset}(),
        DatasetContainer{InMemoryDataset}(),
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
        horizon_length = get_horizon(model)
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
                        horizon = max(simulation_step + time_residual, total_time),
                        resolution = model_resolution,
                    )
                else
                    params[key] = (
                        horizon = max(params[key].horizon, total_time),
                        resolution = min(params[key].resolution, model_resolution),
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
            if !haskey(field_states, key) || get_num_rows(field_states[key]) < value_counts
                field_states[key] = InMemoryDataset(
                    NaN,
                    simulation_initial_time,
                    params[key].resolution,
                    Int(simulation_step / params[key].resolution),
                    value_counts,
                    column_names)
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
                simulation_initial_time,
                min_res,
                cols,
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
    min_res = minimum([v.resolution for v in values(params)])

    for field in fieldnames(DatasetContainer)
        field_containers = getfield(emulation_container, field)
        for (key, value) in field_containers
            !should_write_resulting_value(key) && continue
            column_names = get_column_names(key, value)
            set_dataset!(
                emulator_states,
                key,
                make_system_state(
                    simulation_initial_time,
                    min_res,
                    column_names,
                ),
            )
        end
    end

    for key in get_dataset_keys(decision_states)
        dm_cols = get_column_names(key, get_dataset(decision_states, key))
        if has_dataset(emulator_states, key)
            em_cols = get_column_names(key, get_dataset(emulator_states, key))
            if length(dm_cols) != length(em_cols)
                error(
                    "The number of dimensions between the decision states and emulator states don't match",
                )
            end
            if !isempty(symdiff(first(dm_cols), first(em_cols)))
                error(
                    "Mismatch in column names for dataset $key: $(symdiff(dm_cols, em_cols))",
                )
            end
            continue
        end

        set_dataset!(
            emulator_states,
            key,
            make_system_state(
                simulation_initial_time,
                min_res,
                dm_cols,
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
    store_data::DenseAxisArray{Float64, 2},
    simulation_time::Dates.DateTime,
    model_params::ModelStoreParams,
)
    state_data = get_decision_state_data(state, key)
    column_names = get_column_names(key, state_data)[1]
    model_resolution = get_resolution(model_params)
    state_resolution = get_data_resolution(state_data)
    resolution_ratio = model_resolution ÷ state_resolution
    state_timestamps = state_data.timestamps
    @assert_op resolution_ratio >= 1

    if simulation_time > get_end_of_step_timestamp(state_data)
        state_data_index = 1
        state_data.timestamps[:] .=
            range(
                simulation_time;
                step = state_resolution,
                length = get_num_rows(state_data),
            )
    else
        state_data_index = find_timestamp_index(state_timestamps, simulation_time)
    end

    offset = resolution_ratio - 1
    result_time_index = axes(store_data)[2]
    set_update_timestamp!(state_data, simulation_time)
    for t in result_time_index
        state_range = state_data_index:(state_data_index + offset)
        for name in column_names, i in state_range
            # TODO: We could also interpolate here
            state_data.values[name, i] = store_data[name, t]
        end
        set_last_recorded_row!(state_data, state_range[end])
        state_data_index += resolution_ratio
    end
    return
end

function _get_time_to_recover(event::PSY.GeometricDistributionForcedOutage)
    return PSY.get_mean_time_to_recovery(event)
end

function _get_time_to_recover(event::PSY.TimeSeriesForcedOutage, simulation_time, length)
    ts = PSY.get_time_series(
        IS.SingleTimeSeries,
        event,
        PSY.get_outage_status_scenario(event),
    )
    vals = PSY.get_time_series_values(
        event,
        ts,
        current_time;
        len = state_length,
    )
    return # do the math on the vals difference
end

function update_decision_state!(
    state::SimulationState,
    key::ParameterKey{AvailableStatusChangeParameter, T},
    column_names::Set{String},
    event::PSY.Outage,
    simulation_time::Dates.DateTime,
    ::ModelStoreParams,
) where {T <: PSY.Component}
    event_ocurrence_data = get_system_state_data(state, AvailableStatusChangeParameter(), T)
    event_ocurrence_values = get_last_recorded_value(event_ocurrence_data)
    # This is required since the data for outages (mttr and λ) is always assumed to be on hourly resolution

    mttr_resolution = Dates.Hour(1)
    state_data = get_decision_state_data(state, key)
    state_resolution = get_data_resolution(state_data)
    resolution_ratio = mttr_resolution ÷ state_resolution
    state_timestamps = state_data.timestamps

    mttr = _get_time_to_recover(event, simulation_time, state_length)

    @show current_time = get_current_time(state)
    @show state_timestamps
    @assert_op resolution_ratio >= 1
    # When we are back to the beggining of the simulation step.
    if simulation_time > get_end_of_step_timestamp(state_data)
        state_data_index = 1
        state_data.timestamps[:] .=
            range(
                simulation_time;
                step = state_resolution,
                length = get_num_rows(state_data),
            )
    else
        state_data_index = find_timestamp_index(state_timestamps, simulation_time)
    end
    @show state_data_index
    off_time_step_count =
        Int(mttr) * resolution_ratio + rem(state_data_index, resolution_ratio) #TODO -check if just removing (-1) is correct.
    set_update_timestamp!(state_data, simulation_time)
    for name in column_names
        state_data.values[name, state_data_index] = event_ocurrence_values[name, 1]
        if event_ocurrence_values[name, 1] == 1.0
            # Set future event occurrence to change after the MTTR has passed
            state_data.values[name, state_data_index + off_time_step_count] = 1.0
            @error "update $name to come back online after $off_time_step_count"
        end
    end
    @warn "AvailableStatusChangeParameter decision state after update: $state_data"
    #set_last_recorded_row!(state_data, t)
    return
end

function update_decision_state!(
    state::SimulationState,
    key::ParameterKey{AvailableStatusParameter, T},
    column_names::Set{String},
    event::PSY.GeometricDistributionForcedOutage,
    simulation_time::Dates.DateTime,
    model_params::ModelStoreParams,
) where {T <: PSY.Component}
    event_ocurrence_data =
        get_decision_state_data(state, AvailableStatusChangeParameter(), T)
    state_data = get_decision_state_data(state, key)
    #column_names = get_column_names(key, state_data)[1]
    model_resolution = get_resolution(model_params)
    state_resolution = get_data_resolution(state_data)
    resolution_ratio = model_resolution ÷ state_resolution
    state_timestamps = state_data.timestamps
    @assert_op resolution_ratio >= 1

    if simulation_time > get_end_of_step_timestamp(state_data)
        state_data_index = 1
        state_data.timestamps[:] .=
            range(
                simulation_time;
                step = state_resolution,
                length = get_num_rows(state_data),
            )
    else
        state_data_index = find_timestamp_index(state_timestamps, simulation_time)
    end
    @show current_time = get_current_time(state)
    @show state_data_index
    for name in column_names
        if event_ocurrence_data.values[name, state_data_index] == 1.0
            outage_index = state_data_index + 1     #outage occurs at the following timestep
            while true
                state_data.values[name, outage_index] = 0.0
                if (event_ocurrence_data.values[name, outage_index] == 1.0) ||
                   outage_index == length(state_data.values[name, :])  #If another change is detected or you have reached the end of the state
                    break
                end
                outage_index += 1
            end
        end
    end
    @warn "AvailableStatusParameter decision state after update: $state_data"

    return
end

function update_decision_state!(
    state::SimulationState,
    key::VariableKey{T, U},
    column_names::Set{String},
    event::PSY.GeometricDistributionForcedOutage,
    simulation_time::Dates.DateTime,
    model_params::ModelStoreParams,
) where {T <: VariableType, U <: PSY.Component}
    @error "UPDATE DECISION STATE $key"
    event_ocurrence_data =
        get_decision_state_data(state, AvailableStatusChangeParameter(), U)
    event_status_data = get_decision_state_data(state, AvailableStatusParameter(), U)

    state_data = get_decision_state_data(state, key)
    model_resolution = get_resolution(model_params)
    state_resolution = get_data_resolution(state_data)
    resolution_ratio = model_resolution ÷ state_resolution
    state_timestamps = state_data.timestamps
    @assert_op resolution_ratio >= 1

    if simulation_time > get_end_of_step_timestamp(state_data)
        state_data_index = 1
        state_data.timestamps[:] .=
            range(
                simulation_time;
                step = state_resolution,
                length = get_num_rows(state_data),
            )
    else
        state_data_index = find_timestamp_index(state_timestamps, simulation_time)
    end
    for name in column_names
        if event_ocurrence_data.values[name, state_data_index] == 1.0
            state_data.values[name, (state_data_index + 1):end] .= 0.0
        end
    end
    return
end

function update_decision_state!(
    state::SimulationState,
    key::AuxVarKey{S, T},
    store_data::DenseAxisArray{Float64, 2},
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
            range(
                simulation_time;
                step = state_resolution,
                length = get_num_rows(state_data),
            )
    else
        state_data_index = find_timestamp_index(state_data.timestamps, simulation_time)
    end

    offset = resolution_ratio - 1
    result_time_index = axes(store_data)[2]
    set_update_timestamp!(state_data, simulation_time)

    if resolution_ratio == 1.0
        increment_per_period = 1.0
    elseif state_resolution < Dates.Hour(1) && state_resolution > Dates.Minute(1)
        increment_per_period = Dates.value(Dates.Minute(state_resolution))
    else
        error("Incorrect Problem Resolution specification")
    end

    column_names = axes(state_data.values)[1]
    for t in result_time_index
        state_range = state_data_index:(state_data_index + offset)
        @assert_op state_range[end] <= get_num_rows(state_data)
        for name in column_names, i in state_range
            if t == 1 && i == 1
                state_data.values[name, i] = store_data[name, t] * resolution_ratio
            else
                state_data.values[name, i] =
                    if store_data[name, t] > 0
                        state_data.values[name, i - 1] + increment_per_period
                    else
                        0
                    end
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

function get_decision_state_data(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    return get_decision_state_data(state, VariableKey(T, U))
end

function get_decision_state_data(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return get_decision_state_data(state, AuxVarKey(T, U))
end

function get_decision_state_data(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return get_decision_state_data(state, ConstraintKey(T, U))
end

function get_decision_state_data(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_decision_state_data(state, ParameterKey(T, U))
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
    return get_dataset_values(get_system_states(state), key)[:, 1]
end

function update_system_state!(
    state::DatasetContainer{InMemoryDataset},
    key::OptimizationContainerKey,
    store::SimulationStore,
    model_name::Symbol,
    simulation_time::Dates.DateTime,
)
    em_data = get_em_data(store)
    ix = get_last_recorded_row(em_data, key)
    res = read_result(DenseAxisArray, store, model_name, key, ix)
    dataset = get_dataset(state, key)
    set_update_timestamp!(dataset, simulation_time)
    set_dataset_values!(state, key, 1, res)
    set_last_recorded_row!(dataset, 1)
    return
end

function update_system_state!(
    state::SimulationState,
    key::ParameterKey{AvailableStatusParameter, T},
    column_names_::Set{String},
    event::PSY.GeometricDistributionForcedOutage,
    simulation_time::Dates.DateTime,
    rng,
) where {T <: PSY.Device}
    available_status_parameter = get_system_state_data(state, key)
    available_status_parameter_values = get_last_recorded_value(available_status_parameter)

    available_status_change_parameter =
        get_system_state_data(state, AvailableStatusChangeParameter(), T)
    available_status_change_parameter_values =
        get_last_recorded_value(available_status_change_parameter)

    for name in column_names_
        current_status = available_status_parameter_values[name]
        current_status_change = available_status_change_parameter_values[name]
        if current_status == 1.0 && current_status_change == 1.0
            @error "$name was available and had an outage, setting to unavailable."
            available_status_parameter.values[name, 1] = 0.0
        end
    end
    return
end

function _get_outage_ocurrence(event::PSY.GeometricDistributionForcedOutage, rng)
    λ = PSY.get_outage_transition_probability(event)
    # Outage status = 1.0 means that the unit was subject to an outage
    outage_ocurrence = Float64(rand(rng, Bernoulli(λ)))
    return outage_ocurrence
end

function _get_outage_ocurrence(event::PSY.TimeSeriesForcedOutage, rng, current_time)
    ts = PSY.get_time_series(
        IS.SingleTimeSeries,
        event,
        PSY.get_outage_status_scenario(event),
    )
    vals = PSY.get_time_series_values(
        event,
        ts,
        current_time;
        len = 1,
    )
    return vals
end

function update_system_state!(
    state::SimulationState,
    key::ParameterKey{AvailableStatusChangeParameter, T},
    column_names_::Set{String},
    event::PSY.Outage,
    simulation_time::Dates.DateTime,
    rng,
) where {T <: PSY.Component}
    outage_ocurrence = _get_outage_ocurrence(event, rng, simulation_time)
    @warn "Result of outage occurence draw: $outage_ocurrence"
    sym_state = get_system_states(state)
    system_dataset = get_dataset(sym_state, key)

    # Writes the timestamp of the value used for the update
    available_status_parameter = get_system_state_data(state, AvailableStatusParameter(), T)
    available_status_parameter_values = get_last_recorded_value(available_status_parameter)

    available_status_change_parameter = get_system_state_data(state, key)
    set_update_timestamp!(system_dataset, simulation_time)

    for name in column_names_
        current_status = available_status_parameter_values[name]
        if current_status == 1.0 && outage_ocurrence == 1.0
            available_status_change_parameter.values[name, 1] = outage_ocurrence
            @error "Changed AvailableStatusChangeParameter for $name  to $outage_ocurrence in system state"
        end
    end
    return
end

function update_system_state!(
    state::SimulationState,
    key::VariableKey{T, U},
    column_names::Set{String},
    ::PSY.GeometricDistributionForcedOutage,
    simulation_time::Dates.DateTime,
    rng,
) where {T <: VariableType, U <: PSY.Component}
    sym_state = get_system_states(state)
    event_ocurrence_data = get_system_state_data(state, AvailableStatusChangeParameter(), U)
    event_ocurrence_values = get_last_recorded_value(event_ocurrence_data)

    system_dataset = get_dataset(sym_state, key)
    current_status_data = get_system_state_data(state, key)
    current_status_values = get_last_recorded_value(current_status_data)
    set_update_timestamp!(system_dataset, simulation_time)
    for name in column_names
        if event_ocurrence_values[name] == 1.0
            old_value = current_status_values[name]
            current_status_values[name] = 0.0
            @error "Changed $T for $name from: $old_value to: 0.0"
        end
    end
    return
end

function update_system_state!(
    state::DatasetContainer{InMemoryDataset},
    key::OptimizationContainerKey,
    decision_state::DatasetContainer{InMemoryDataset},
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

    # Note: This protection is disabled because the rate of update of the emulator
    # is now higher than the decision rate. If the event happens in the middle of an "hourly"
    # rate decision variable then the whole hour is updated creating a problem.

    # New logic will be needed to maintain the protection.
    #if get_update_timestamp(system_dataset) > ts
    #    error("Trying to update with past data a future state timestamp \\
    #        key: $(encode_key_as_string(key)), $(simulation_time), $ts")
    #end

    # Writes the timestamp of the value used for the update
    set_update_timestamp!(system_dataset, ts)
    # Keep coordination between fields. System state is an array of size 1
    system_dataset.timestamps[1] = ts
    data_set_value = get_dataset_value(decision_dataset, simulation_time)
    set_dataset_values!(state, key, 1, data_set_value)
    # This value shouldn't be other than one and after one execution is no-op.
    set_last_recorded_row!(system_dataset, 1)
    return
end

function update_system_state!(
    state::DatasetContainer{InMemoryDataset},
    key::AuxVarKey{T, PSY.ThermalStandard},
    decision_state::DatasetContainer{InMemoryDataset},
    simulation_time::Dates.DateTime,
) where {T <: Union{TimeDurationOn, TimeDurationOff}}
    decision_dataset = get_dataset(decision_state, key)
    # Gets the timestamp of the value used for the update, which might not match exactly the
    # simulation time since the value might have not been updated yet

    ts = get_value_timestamp(decision_dataset, simulation_time)
    system_dataset = get_dataset(state, key)
    system_state_resolution = get_data_resolution(system_dataset)
    decision_state_resolution = get_data_resolution(decision_dataset)

    decision_state_value = get_dataset_value(decision_dataset, simulation_time)

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
    time_ratio = (decision_state_resolution / system_state_resolution)
    # Don't use set_dataset_values!(state, key, 1, decision_state_value).
    # For the time variables we need to grab the values to avoid mutation of the
    # dataframe row
    set_value!(system_dataset, values(decision_state_value) .* time_ratio, 1)
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

function get_system_state_value(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_system_state_value(state, ParameterKey(T, U))
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

function get_system_state_data(
    state::SimulationState,
    ::T,
    ::Type{U},
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_system_state_data(state, ParameterKey(T, U))
end
