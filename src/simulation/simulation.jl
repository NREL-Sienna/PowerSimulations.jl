"""
    Simulation(
        steps::Int
        models::SimulationModels,
        sequence::Union{Nothing, SimulationSequence},
        simulation_folder::String,
        name::String,
        internal::Union{Nothing, SimulationInternal},
    )
"""
mutable struct Simulation
    steps::Int
    models::SimulationModels
    initial_time::Union{Nothing, Dates.DateTime}
    sequence::SimulationSequence
    simulation_folder::String
    name::String
    internal::Union{Nothing, SimulationInternal}

    function Simulation(;
        sequence::SimulationSequence,
        name::String,
        steps::Int,
        models::SimulationModels,
        simulation_folder::String,
        initial_time=nothing,
    )
        for model in get_decision_models(models)
            if model.internal.simulation_info.sequence_uuid != sequence.uuid
                model_name = get_name(model)
                throw(
                    IS.ConflictingInputsError(
                        "The decision model definition for $model_name doesn't correspond to the simulation sequence",
                    ),
                )
            end
        end
        em = get_emulation_model(models)
        if em !== nothing
            if em.internal.simulation_info.sequence_uuid != sequence.uuid
                model_name = get_name(em)
                throw(
                    IS.ConflictingInputsError(
                        "The emulation model definition for $model_name doesn't correspond to the simulation sequence",
                    ),
                )
            end
        end
        new(steps, models, initial_time, sequence, simulation_folder, name, nothing)
    end
end

"""
    Simulation(directory::AbstractString)

Constructs Simulation from a serialized directory. Callers should pass any kwargs here that
they passed to the original Simulation.

# Arguments

  - `directory::AbstractString`: the directory returned from the call to serialize
  - `model_info::Dict`: Two-level dictionary containing model parameters that cannot be
    serialized. The outer dict should be keyed by the problem name. The inner dict must contain
    'optimizer' and may contain 'jump_model'. These should be the same values used for the
    original simulation.
"""
function Simulation(directory::AbstractString, model_info::Dict)
    return deserialize_model(Simulation, directory, model_info)
end

###################### Simulation Accessor Functions ####################
function get_base_powers(sim::Simulation)
    base_powers = Dict()
    for model in get_models(sim)
        base_powers[get_name(model)] = PSY.get_base_power(get_system(model))
    end
    return base_powers
end

get_initial_time(sim::Simulation) = sim.initial_time
get_sequence(sim::Simulation) = sim.sequence
get_steps(sim::Simulation) = sim.steps
get_current_time(sim::Simulation) = get_current_time(get_simulation_state(sim))
get_simulation_model(s::Simulation, name) = get_simulation_model(get_models(s), name)
get_models(sim::Simulation) = sim.models
get_simulation_dir(sim::Simulation) = dirname(sim.internal.logs_dir)
get_simulation_files_dir(sim::Simulation) = sim.internal.sim_files_dir
get_store_dir(sim::Simulation) = sim.internal.store_dir
get_simulation_status(sim::Simulation) = sim.internal.status
get_simulation_build_status(sim::Simulation) = sim.internal.build_status
get_simulation_state(sim::Simulation) = sim.internal.simulation_state
set_simulation_store!(sim::Simulation, store) = sim.internal.store = store
get_simulation_store(sim::Simulation) = sim.internal.store
get_results_dir(sim::Simulation) = sim.internal.results_dir
get_models_dir(sim::Simulation) = sim.internal.models_dir

get_interval(sim::Simulation, name::Symbol) = get_interval(sim.sequence, name)

function get_simulation_time(sim::Simulation, problem_number::Int)
    return sim.internal.date_ref[problem_number]
end

get_ini_cond_chronology(sim::Simulation) = get_sequence(sim).ini_cond_chronology
get_name(sim::Simulation) = sim.name
get_simulation_folder(sim::Simulation) = sim.simulation_folder
get_execution_order(sim::Simulation) = get_sequence(sim).execution_order
get_current_execution_index(sim::Simulation) = get_sequence(sim).current_execution_index
get_logs_folder(sim::Simulation) = sim.internal.logs_dir
get_recorder_folder(sim::Simulation) = sim.internal.recorder_dir
get_console_level(sim::Simulation) = sim.internal.console_level
get_file_level(sim::Simulation) = sim.internal.file_level

set_simulation_status!(sim::Simulation, status) = sim.internal.status = status
set_simulation_build_status!(sim::Simulation, status::BuildStatus) =
    sim.internal.build_status = status

function set_current_time!(sim::Simulation, val::Dates.DateTime)
    set_current_time!(get_simulation_state(sim), val)
    return
end

function _get_simulation_initial_times!(sim::Simulation)
    model_initial_times = OrderedDict{Int, Vector{Dates.DateTime}}()
    sim_ini_time = get_initial_time(sim)
    for (model_number, model) in enumerate(get_models(sim).decision_models)
        system = get_system(model)
        model_horizon = get_horizon(model)
        system_horizon = PSY.get_forecast_horizon(system)
        system_interval = PSY.get_forecast_interval(system)
        if model_horizon > system_horizon
            throw(
                IS.ConflictingInputsError(
                    "$(get_name(model)) model horizon ($model_horizon) and forecast horizon ($system_horizon) are not compatible",
                ),
            )
        end
        model_initial_times[model_number] = PSY.get_forecast_initial_times(system)
        for (ix, element) in enumerate(model_initial_times[model_number][1:(end - 1)])
            if !(element + system_interval == model_initial_times[model_number][ix + 1])
                throw(
                    IS.ConflictingInputsError(
                        "The sequence of forecasts in the model's systems are invalid",
                    ),
                )
            end
        end
        if sim_ini_time !== nothing &&
           !mapreduce(x -> x == sim_ini_time, |, model_initial_times[model_number])
            throw(
                IS.ConflictingInputsError(
                    "The specified simulation initial_time $sim_ini_time isn't contained in model $(get_name(model)).
Manually provided initial times have to be compatible with the specified interval and horizon in the models.",
                ),
            )
        end
    end
    if get_initial_time(sim) === nothing
        sim.initial_time = model_initial_times[1][1]
        @debug("Initial Simulation timestamp will be infered from the data. \\
               Initial Simulation timestamp set to $(sim.initial_time)")
    end
    if get_models(sim).emulation_model !== nothing
        em = get_models(sim).emulation_model
        system = get_system(get_models(sim).emulation_model)
        ini_time, ts_length =
            PSY.check_time_series_consistency(system, PSY.SingleTimeSeries)
        resolution = PSY.get_time_series_resolution(system)
        em_available_times = range(ini_time, step=resolution, length=ts_length)
        if get_initial_time(sim) ∉ em_available_times
            throw(
                IS.ConflictingInputsError(
                    "The simulation initial_time $sim_ini_time isn't contained in the
                    emulation model $(get_name(em)).",
                ),
            )
        else
            model_initial_times[length(model_initial_times) + 1] = [sim.initial_time]
        end
    end
    set_current_time!(sim, sim.initial_time)
    return model_initial_times
end

function _check_steps(
    sim::Simulation,
    model_initial_times::OrderedDict{Int, Vector{Dates.DateTime}},
)
    sequence = get_sequence(sim)
    execution_order = get_execution_order(sequence)
    for (model_number, model) in enumerate(get_models(sim).decision_models)
        execution_counts = get_executions(model)
        # Checks the consistency between two methods of calculating the number of executions
        total_model_executions = length(findall(x -> x == model_number, execution_order))
        @assert_op total_model_executions == execution_counts

        forecast_count = length(model_initial_times[model_number])
        if get_steps(sim) * execution_counts > forecast_count
            throw(
                IS.ConflictingInputsError(
                    "The number of available time series ($(forecast_count)) is not enough to perform the
desired amount of simulation steps ($(sim.steps*get_execution_count(model))).",
                ),
            )
        end
    end
    return
end

function _check_folder(sim::Simulation)
    folder = get_simulation_folder(sim)
    !isdir(folder) && throw(IS.ConflictingInputsError("Specified folder is not valid"))
    try
        mkdir(joinpath(folder, "fake"))
        rm(joinpath(folder, "fake"))
    catch e
        throw(IS.ConflictingInputsError("Specified folder does not have write access [$e]"))
    end
end

function _build_decision_models!(sim::Simulation)
    for (model_number, model) in enumerate(get_decision_models(get_models(sim)))
        @info("Building problem $(get_name(model))")
        initial_time = get_initial_time(sim)
        set_initial_time!(model, initial_time)
        output_dir = joinpath(get_models_dir(sim), string(get_name(model)))
        mkpath(output_dir)
        set_output_dir!(model, output_dir)
        try
            TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Problem $(get_name(model))" begin
                # TODO-PJ: Temporary while are able to switch from PJ to POI
                container = get_optimization_container(model)
                container.built_for_recurrent_solves = true
                build_impl!(model)
            end
            sim.internal.date_ref[model_number] = initial_time
            set_status!(model, BuildStatus.BUILT)
            # TODO: Disable check of variable bounds ?
            _pre_solve_model_checks(model)
        catch
            set_status!(model, BuildStatus.FAILED)
            rethrow()
        end
    end
    return
end

function _build_emulation_model!(sim::Simulation)
    model = get_emulation_model(get_models(sim))

    if model === nothing
        return
    end

    try
        initial_time = get_initial_time(sim)
        set_initial_time!(model, initial_time)
        output_dir = joinpath(get_models_dir(sim), string(get_name(model)))
        mkpath(output_dir)
        set_output_dir!(model, output_dir)
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Problem $(get_name(model))" begin
            build_impl!(model)
        end
        sim.internal.date_ref[length(sim.internal.date_ref) + 1] = initial_time
        set_status!(model, BuildStatus.BUILT)
    catch
        set_status!(model, BuildStatus.FAILED)
        rethrow()
    end
    return
end

function _initialize_simulation_state!(sim::Simulation)
    step_resolution = get_step_resolution(get_sequence(sim))
    simulation_models = get_models(sim)
    initialize_simulation_state!(
        get_simulation_state(sim),
        simulation_models,
        step_resolution,
        get_initial_time(sim),
    )
    return
end

function _get_model_store_requirements!(
    rules::CacheFlushRules,
    model::OperationModel,
    num_rows::Int,
)
    model_name = get_name(model)
    horizon = get_horizon(model)
    reqs = SimulationModelStoreRequirements()
    container = get_optimization_container(model)

    for (key, array) in get_duals(container)
        !should_write_resulting_value(key) && continue
        reqs.duals[key] = _calc_dimensions(array, key, num_rows, horizon)
        add_rule!(rules, model_name, key, true)
    end

    for (key, param_container) in get_parameters(container)
        !should_write_resulting_value(key) && continue
        array = get_parameter_array(param_container)
        reqs.parameters[key] = _calc_dimensions(array, key, num_rows, horizon)
        add_rule!(rules, model_name, key, false)
    end

    for (key, array) in get_variables(container)
        !should_write_resulting_value(key) && continue
        reqs.variables[key] = _calc_dimensions(array, key, num_rows, horizon)
        add_rule!(rules, model_name, key, true)
    end

    for (key, array) in get_aux_variables(container)
        !should_write_resulting_value(key) && continue
        reqs.aux_variables[key] = _calc_dimensions(array, key, num_rows, horizon)
        add_rule!(rules, model_name, key, true)
    end

    for (key, array) in get_expressions(container)
        !should_write_resulting_value(key) && continue
        reqs.expressions[key] = _calc_dimensions(array, key, num_rows, horizon)
        add_rule!(rules, model_name, key, false)
    end

    return reqs
end

function _get_emulation_store_requirements(sim::Simulation)
    sim_state = get_simulation_state(sim)
    system_state = get_system_states(sim_state)
    sim_time = get_steps(sim) * get_step_resolution(get_sequence(sim))
    reqs = SimulationModelStoreRequirements()

    for (key, state_values) in get_duals_values(system_state)
        !should_write_resulting_value(key) && continue
        dims = sim_time ÷ get_data_resolution(state_values)
        cols = get_column_names(key, state_values)
        reqs.duals[key] = Dict("columns" => cols, "dims" => (dims, length(cols)))
    end

    for (key, state_values) in get_parameters_values(system_state)
        !should_write_resulting_value(key) && continue
        dims = sim_time ÷ get_data_resolution(state_values)
        cols = get_column_names(key, state_values)
        reqs.parameters[key] = Dict("columns" => cols, "dims" => (dims, length(cols)))
    end

    for (key, state_values) in get_variables_values(system_state)
        !should_write_resulting_value(key) && continue
        dims = sim_time ÷ get_data_resolution(state_values)
        cols = get_column_names(key, state_values)
        reqs.variables[key] = Dict("columns" => cols, "dims" => (dims, length(cols)))
    end

    for (key, state_values) in get_aux_variables_values(system_state)
        !should_write_resulting_value(key) && continue
        dims = sim_time ÷ get_data_resolution(state_values)
        cols = get_column_names(key, state_values)
        reqs.aux_variables[key] = Dict("columns" => cols, "dims" => (dims, length(cols)))
    end

    for (key, state_values) in get_expression_values(system_state)
        !should_write_resulting_value(key) && continue
        dims = sim_time ÷ get_data_resolution(state_values)
        cols = get_column_names(key, state_values)
        reqs.expressions[key] = Dict("columns" => cols, "dims" => (dims, length(cols)))
    end
    return reqs
end

function _initialize_problem_storage!(
    sim::Simulation,
    cache_size_mib,
    min_cache_flush_size_mib,
)
    sequence = get_sequence(sim)
    executions_by_model = sequence.executions_by_model
    models = get_models(sim)
    decision_model_store_params = OrderedDict{Symbol, ModelStoreParams}()
    dm_model_req = Dict{Symbol, SimulationModelStoreRequirements}()
    rules = CacheFlushRules(
        max_size=cache_size_mib * MiB,
        min_flush_size=trunc(min_cache_flush_size_mib * MiB),
    )
    for model in get_decision_models(models)
        model_name = get_name(model)
        decision_model_store_params[model_name] = model.internal.store_parameters
        num_executions = executions_by_model[model_name]
        num_rows = num_executions * get_steps(sim)
        dm_model_req[model_name] = _get_model_store_requirements!(rules, model, num_rows)
    end

    em = get_emulation_model(models)
    if em === nothing
        base_params = last(collect(values(decision_model_store_params)))
        resolution = minimum([v.resolution for v in values(decision_model_store_params)])
        emulation_model_store_params = OrderedDict(
            :Emulator => ModelStoreParams(
                get_step_resolution(sequence) ÷ resolution, # Num Executions
                1,
                resolution, # Interval
                resolution, # Resolution
                get_base_power(base_params),
                get_system_uuid(base_params),
            ),
        )
    else
        emulation_model_store_params =
            OrderedDict(Symbol(get_name(em)) => em.internal.store_parameters)
    end

    em_model_req = _get_emulation_store_requirements(sim)

    simulation_store_params = SimulationStoreParams(
        get_initial_time(sim),
        get_step_resolution(sequence),
        get_steps(sim),
        decision_model_store_params,
        emulation_model_store_params,
    )
    @debug "initialized problem requirements" simulation_store_params
    store = get_simulation_store(sim)

    initialize_problem_storage!(
        store,
        simulation_store_params,
        dm_model_req,
        em_model_req,
        rules,
    )
    return simulation_store_params
end

function _build!(sim::Simulation, serialize::Bool)
    set_simulation_build_status!(sim, BuildStatus.IN_PROGRESS)
    problem_initial_times = _get_simulation_initial_times!(sim)
    sequence = get_sequence(sim)
    step_resolution = get_step_resolution(sequence)
    simulation_models = get_models(sim)
    for (ix, model) in enumerate(get_decision_models(simulation_models))
        problem_interval = get_interval(sequence, model)
        # Note to devs: Here we are setting the number of operations problem executions we
        # will see for every step of the simulation. The step of the simulation is determined
        # by the first decision problem interval
        if ix == 1
            set_executions!(model, 1)
        else
            if step_resolution % problem_interval != Dates.Millisecond(0)
                error(
                    "The $(get_name(model)) problem interval is not an integer fraction of the simulation step",
                )
            end
            set_executions!(model, Int(step_resolution / problem_interval))
        end
    end

    em = get_emulation_model(simulation_models)
    if em !== nothing
        system = get_system(em)
        em_resolution = PSY.get_time_series_resolution(system)
        set_executions!(em, get_steps(sim) * Int(step_resolution / em_resolution))
    end

    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Check Steps" begin
        _check_steps(sim, problem_initial_times)
    end

    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build Problems" begin
        _build_decision_models!(sim)
        _build_emulation_model!(sim)
    end

    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Initialize Simulation State" begin
        _initialize_simulation_state!(sim)
    end

    if serialize
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Serializing Simulation Files" begin
            serialize_simulation(sim)
        end
        for model in get_decision_models(simulation_models)
            serialize_problem(model)
        end
        if em !== nothing
            serialize_problem(em)
        end
    end
    return
end

function _set_simulation_internal!(
    sim::Simulation,
    output_dir,
    recorders,
    console_level,
    file_level,
)
    sim.internal = SimulationInternal(
        sim.steps,
        get_models(sim),
        get_simulation_folder(sim),
        get_name(sim),
        output_dir,
        recorders,
        console_level,
        file_level,
    )
    return
end

"""
    build!(sim::Simulation)

Build the Simulation, problems and the related folder structure

# Arguments

  - `sim::Simulation`: simulation object
  - `output_dir` = nothing: Name of the output directory for the simulation. If nothing, the
    folder will have the same name as the simulation
  - `serialize::Bool = true`: serializes the simulation objects in the simulation
  - `recorders::Vector{Symbol} = []`: recorder names to register
  - `console_level = Logging.Error`:
  - `file_level = Logging.Info`:

Throws an exception if name is passed and the directory already exists.
"""
function build!(
    sim::Simulation;
    output_dir=nothing,
    recorders=[],
    console_level=Logging.Error,
    file_level=Logging.Info,
    serialize=true,
    initialize_problem=false,
)
    TimerOutputs.reset_timer!(BUILD_PROBLEMS_TIMER)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build Simulation" begin
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Initialize Simulation Internal" begin
            _check_folder(sim)
            _set_simulation_internal!(sim, output_dir, recorders, console_level, file_level)
        end
        file_mode = "w"
        logger = configure_logging(sim.internal, file_mode)
        register_recorders!(sim.internal, file_mode)
        try
            Logging.with_logger(logger) do
                try
                    _build!(sim, serialize)
                    set_simulation_build_status!(sim, BuildStatus.BUILT)
                    set_simulation_status!(sim, RunStatus.READY)
                catch e
                    @error "Simulation build failed" exception = (e, catch_backtrace())
                    set_simulation_build_status!(sim, BuildStatus.FAILED)
                    set_simulation_status!(sim, RunStatus.NOT_READY)
                    rethrow(e)
                end
            end
        finally
            unregister_recorders!(sim.internal)
            close(logger)
        end
    end
    initialize_problem && _initial_conditions_problems!(sim)
    @info "\n$(BUILD_PROBLEMS_TIMER)\n"
    return get_simulation_build_status(sim)
end

function _apply_warm_start!(model::OperationModel)
    container = get_optimization_container(model)
    # If the model was used to retrieve duals from an MILP the logic has to be different and
    # the results need to be read from the primal cache
    if isempty(container.primal_values_cache)
        jump_model = get_jump_model(container)
        all_vars = JuMP.all_variables(jump_model)
        all_vars_value = jump_value.(all_vars)
        JuMP.set_start_value.(all_vars, all_vars_value)
    else
        for (var_key, variable_value) in container.primal_values_cache.variables_cache
            variable = get_variable(container, var_key)
            JuMP.set_start_value.(variable, variable_value)
        end
    end
    return
end

function _get_next_problem_initial_time(sim::Simulation, model_name::Symbol)
    current_time = get_current_time(sim)
    sequence = get_sequence(sim)
    current_exec_index = sequence.current_execution_index
    exec_order = get_execution_order(sequence)

    if length(exec_order) > 1 && (current_exec_index + 1 > length(exec_order)) # Moving to the next step
        next_initial_time = get_simulation_time(sim, exec_order[1])
    elseif length(exec_order) == 1 ||
           exec_order[current_exec_index + 1] == exec_order[current_exec_index] # Solving the same problem again
        current_model_interval = get_interval(sim.sequence, model_name)
        next_initial_time = current_time + current_model_interval
    else # Solving another problem next
        next_initial_time = get_simulation_time(sim, exec_order[current_exec_index + 1])
    end
    return next_initial_time
end

function _update_system_state!(sim::Simulation, model_name::Symbol)
    sim_state = get_simulation_state(sim)
    system_state = get_system_states(sim_state)
    decision_state = get_decision_states(sim_state)
    simulation_time = get_current_time(sim_state)
    next_stage_initial_time = _get_next_problem_initial_time(sim, model_name)

    for key in get_dataset_keys(decision_state)
        state_data = get_dataset(decision_state, key)
        last_update = get_update_timestamp(decision_state, key)

        if last_update > simulation_time
            error("Something went really wrong. Please report this error. \\
            last_update: $(last_update) \\
            simulation_time: $(simulation_time) \\
            key: $(encode_key_as_string(key))")
        end

        resolution = get_data_resolution(state_data)
        update_timestamp = max(next_stage_initial_time - resolution, simulation_time)
        if update_timestamp < get_update_timestamp(system_state, key)
            error("The update overwrites more recent data with past data")
        elseif update_timestamp > get_update_timestamp(system_state, key)
            update_system_state!(system_state, key, decision_state, update_timestamp)
        else
            @assert_op update_timestamp == get_update_timestamp(system_state, key)
        end
    end

    IS.@record :execution StateUpdateEvent(simulation_time, model_name, "SystemState")
    return
end

function _update_system_state!(sim::Simulation, model::DecisionModel)
    _update_system_state!(sim, get_name(model))
    return
end

function _update_system_state!(sim::Simulation, model::EmulationModel)
    sim_state = get_simulation_state(sim)
    simulation_time = get_current_time(sim)
    system_state = get_system_states(sim_state)
    store = get_simulation_store(sim)
    em_model_name = get_name(model)
    for key in get_container_keys(get_optimization_container(model))
        !should_write_resulting_value(key) && continue
        update_system_state!(system_state, key, store, em_model_name, simulation_time)
    end
    IS.@record :execution StateUpdateEvent(simulation_time, em_model_name, "SystemState")
    return
end

function _update_simulation_state!(sim::Simulation, model::EmulationModel)
    # Order of these operations matters. Do not reverse.
    # This will update the state with the results of the store first and then fill
    # the remaning values with the decision state.
    _update_system_state!(sim, model)
    _update_system_state!(sim, get_name(model))
    return
end

function _update_simulation_state!(sim::Simulation, model::DecisionModel)
    model_name = get_name(model)
    store = get_simulation_store(sim)
    simulation_time = get_current_time(sim)
    state = get_simulation_state(sim)
    model_params = get_decision_model_params(store, model_name)
    for field in fieldnames(DatasetContainer)
        for key in list_decision_model_keys(store, model_name, field)
            !has_dataset(get_decision_states(state), key) && continue
            res = read_result(DataFrames.DataFrame, store, model_name, key, simulation_time)
            update_decision_state!(state, key, res, simulation_time, model_params)
        end
    end
    IS.@record :execution StateUpdateEvent(simulation_time, model_name, "DecisionState")
    return
end

function _write_state_to_store!(store::SimulationStore, sim::Simulation)
    sim_state = get_simulation_state(sim)
    system_state = get_system_states(sim_state)
    model_name = get_last_decision_model(sim_state)
    em_store = get_em_data(store)
    simulation_time = get_current_time(sim)
    sim_ini_time = get_initial_time(sim)
    state_resolution = get_system_states_resolution(sim_state)
    for key in get_dataset_keys(system_state)
        store_update_time = get_last_updated_timestamp(em_store, key)
        state_update_time = get_update_timestamp(system_state, key)
        # If the store is outdated w.r.t to the state
        @assert store_update_time <= simulation_time
        if store_update_time < state_update_time
            _update_timestamp = max(store_update_time + state_resolution, sim_ini_time)
            while _update_timestamp <= state_update_time
                state_values = get_decision_state_value(sim_state, key, _update_timestamp)
                ix = get_last_recorded_row(em_store, key) + 1
                write_result!(store, model_name, key, ix, _update_timestamp, state_values)
                _update_timestamp += state_resolution
            end
        end
    end
    return
end

"""
Default problem update function for most problems with no customization
"""
function update_model!(model::OperationModel, sim::Simulation)
    if get_requires_rebuild(model)
        # TODO: Implement this case where the model is re-built
        # build_impl!(model)
    else
        update_model!(model, get_simulation_state(sim), get_ini_cond_chronology(sim))
    end
    return
end

function _execute!(
    sim::Simulation;
    cache_size_mib=DEFAULT_SIMULATION_STORE_CACHE_SIZE_MiB,
    min_cache_flush_size_mib=MIN_CACHE_FLUSH_SIZE_MiB,
    exports=nothing,
    enable_progress_bar=progress_meter_enabled(),
    disable_timer_outputs=false,
)
    @assert sim.internal !== nothing

    set_simulation_status!(sim, RunStatus.RUNNING)
    execution_order = get_execution_order(sim)
    steps = get_steps(sim)
    num_executions = steps * length(execution_order)
    store_params =
        _initialize_problem_storage!(sim, cache_size_mib, min_cache_flush_size_mib)
    status = RunStatus.RUNNING
    if exports !== nothing
        if !(exports isa SimulationResultsExport)
            exports = SimulationResultsExport(exports, store_params)
        end

        if exports.path === nothing
            exports.path = get_results_dir(sim)
        end
    end
    sequence = get_sequence(sim)
    models = get_models(sim)

    prog_bar = ProgressMeter.Progress(num_executions; enabled=enable_progress_bar)
    disable_timer_outputs && TimerOutputs.disable_timer!(RUN_SIMULATION_TIMER)
    store = get_simulation_store(sim)
    for step in 1:steps
        IS.@record :simulation_status SimulationStepEvent(
            get_current_time(sim),
            step,
            "start",
        )
        for (ix, model_number) in enumerate(execution_order)
            model = get_simulation_model(models, model_number)
            model_name = get_name(model)
            set_current_time!(sim, sim.internal.date_ref[model_number])
            sequence.current_execution_index = ix
            current_time = get_current_time(sim)
            IS.@record :simulation_status ProblemExecutionEvent(
                current_time,
                step,
                model_name,
                "start",
            )

            ProgressMeter.update!(
                prog_bar,
                (step - 1) * length(execution_order) + ix;
                showvalues=[
                    (:Step, step),
                    (:model, model_name),
                    (:("Simulation Timestamp"), get_current_time(sim)),
                ],
            )

            TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execute $(model_name)" begin
                if !is_built(model)
                    error("$(model_name) status is not BuildStatus.BUILT")
                end

                # Is first run of first problem? Yes -> don't update problem

                TimerOutputs.@timeit RUN_SIMULATION_TIMER "Update $(model_name)" begin
                    !(step == 1 && ix == 1) && update_model!(model, sim)
                end

                TimerOutputs.@timeit RUN_SIMULATION_TIMER "Solve $(model_name)" begin
                    status = solve!(step, model, current_time, store; exports=exports)
                end # Run problem Timer

                TimerOutputs.@timeit RUN_SIMULATION_TIMER "Update State" begin
                    if status == RunStatus.SUCCESSFUL
                        # TODO: _update_simulation_state! can use performance improvements
                        _update_simulation_state!(sim, model)
                        if model_number == execution_order[end]
                            _update_system_state!(sim, model)
                            _write_state_to_store!(store, sim)
                        end
                    end
                end

                sim.internal.run_count[step][model_number] += 1
                sim.internal.date_ref[model_number] += get_interval(sequence, model_name)

                # _apply_warm_start! can only be called once all the operations that read solutions
                # from the optimization container have been called.
                # See https://github.com/NREL-SIIP/PowerSimulations.jl/pull/793#discussion_r761545526
                # for reference
                if warm_start_enabled(model)
                    _apply_warm_start!(model)
                end

                IS.@record :simulation_status ProblemExecutionEvent(
                    get_current_time(sim),
                    step,
                    model_name,
                    "done",
                )
            end #execution problem timer
        end # execution order for loop

        IS.@record :simulation_status SimulationStepEvent(
            get_current_time(sim),
            step,
            "done",
        )
    end # Steps for loop
    return
end

"""
    execute!(sim::Simulation; kwargs...)

Solves the simulation model for sequential Simulations.

# Arguments

  - `sim::Simulation=sim`: simulation object created by Simulation()

The optional keyword argument `exports` controls exporting of results to CSV files as
the simulation runs. Refer to [`export_results`](@ref) for a description of this argument.

# Example

sim = Simulation("Test", 7, problems, "/Users/folder")
execute!(sim::Simulation; kwargs...)
"""
function execute!(sim::Simulation; kwargs...)
    file_mode = "a"
    logger = configure_logging(sim.internal, file_mode)
    register_recorders!(sim.internal, file_mode)

    # Undocumented option for test & dev only.
    in_memory = get(kwargs, :in_memory, false)
    store_type = in_memory ? InMemorySimulationStore : HdfSimulationStore

    if (get_simulation_build_status(sim) != BuildStatus.BUILT) ||
       (get_simulation_status(sim) != RunStatus.READY)
        error("Simulation status is invalid, you need to rebuild the simulation")
    end
    try
        Logging.with_logger(logger) do
            open_store(store_type, get_store_dir(sim), "w") do store
                set_simulation_store!(sim, store)
                try
                    TimerOutputs.reset_timer!(RUN_SIMULATION_TIMER)
                    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execute Simulation" begin
                        _execute!(sim; [k => v for (k, v) in kwargs if k != :in_memory]...)
                    end
                    @info ("\n$(RUN_SIMULATION_TIMER)\n")
                    set_simulation_status!(sim, RunStatus.SUCCESSFUL)
                    log_cache_hit_percentages(store)
                catch e
                    set_simulation_status!(sim, RunStatus.FAILED)
                    @error "simulation failed" exception = (e, catch_backtrace())
                end
            end
        end
    finally
        _empty_problem_caches!(sim)
        unregister_recorders!(sim.internal)
        close(logger)
    end

    if !in_memory
        compute_file_hash(get_store_dir(sim), HDF_FILENAME)
    end

    serialize_status(sim)
    return get_simulation_status(sim)
end

struct SimulationSerializationWrapper
    steps::Int
    models::Vector{Symbol}
    initial_time::Union{Nothing, Dates.DateTime}
    sequence::Union{Nothing, SimulationSequence}
    simulation_folder::String
    name::String
end

function _empty_problem_caches!(sim::Simulation)
    models = get_models(sim)
    for model in get_decision_models(models)
        empty_time_series_cache!(model)
    end
    return
end

"""
    serialize_simulation(sim::Simulation, path = ".")

Serialize the simulation to a directory in path.

Return the serialized simulation directory name that is created.

# Arguments

  - `sim::Simulation`: simulation to serialize
  - `path = "."`: path in which to create the serialzed directory
  - `force = false`: If true, delete the directory if it already exists. Otherwise, it will
    throw an exception.
"""
function serialize_simulation(sim::Simulation; path=nothing, force=false)
    if path === nothing
        directory = get_simulation_files_dir(sim)
    else
        directory = path
    end
    problems = get_model_names(get_models(sim))

    if !isempty(readdir(directory)) && !force
        throw(
            ArgumentError(
                "$directory has files already: $(readdir(directory)). Please delete them or pass force = true.",
            ),
        )
    end
    rm(directory, recursive=true, force=true)
    mkdir(directory)

    filename = joinpath(directory, SIMULATION_SERIALIZATION_FILENAME)
    obj = SimulationSerializationWrapper(
        get_steps(sim),
        problems,
        get_initial_time(sim),
        get_sequence(sim),
        get_simulation_dir(sim),
        get_name(sim),
    )
    Serialization.serialize(filename, obj)
    @info "Serialized simulation name = $(get_name(sim))" directory
    return directory
end

function deserialize_model(
    ::Type{Simulation},
    directory::AbstractString,
    problem_info::Dict,
)
    error("deserialization of a Simulation is not currently supported")
    orig = pwd()
    cd(directory)

    try
        filename = SIMULATION_SERIALIZATION_FILENAME
        if !ispath(filename)
            throw(ArgumentError("$filename does not exist"))
        end

        obj = Serialization.deserialize(filename)
        if !(obj isa SimulationSerializationWrapper)
            throw(
                IS.DataFormatError("deserialized object has incorrect type $(typeof(obj))"),
            )
        end

        models = Vector{DecisionModel{<:DecisionProblem}}()
        for name in obj.models
            model =
                deserialize_problem(DecisionProblem, joinpath("problems", "$(name).bin"))
            if !haskey(problem_info[key], "optimizer")
                throw(ArgumentError("problem_info must define 'optimizer'"))
            end
            push!(
                models,
                wrapper.problem_type(
                    name,
                    wrapper.template,
                    sys,
                    restore_from_copy(
                        wrapper.settings;
                        optimizer=problem_info[key]["optimizer"],
                    ),
                    get(problem_info[key], "jump_model", nothing),
                ),
            )
        end

        sim = Simulation(;
            name=obj.name,
            steps=obj.steps,
            models=SimulationModels(problems...),
            problems_sequence=obj.sequence,
            simulation_folder=obj.simulation_folder,
        )
        return sim
    finally
        cd(orig)
    end
end

function serialize_status(sim::Simulation)
    data = Dict("run_status" => string(get_simulation_status(sim)))
    filename = joinpath(get_results_dir(sim), "status.json")
    open(filename, "w") do io
        JSON3.write(io, data)
    end

    return
end

function deserialize_status(sim::Simulation)
    return deserialize_status(get_results_dir(sim))
end

function deserialize_status(results_path::AbstractString)
    filename = joinpath(results_path, "status.json")
    if !isfile(filename)
        error("run status file $filename does not exist")
    end

    data = open(filename, "r") do io
        JSON3.read(io, Dict)
    end

    return get_enum_value(RunStatus, data["run_status"])
end
