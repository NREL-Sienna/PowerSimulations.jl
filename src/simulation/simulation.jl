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
        initial_time = nothing,
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
# TODO: this description is probably wrong
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
get_models(sim::Simulation) = sim.models
get_model(sim::Simulation, ix::Int) = sim.models[ix]
get_model(sim::Simulation, name::Symbol) = get_model(sim.models, name)
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
IS.get_name(sim::Simulation) = sim.name
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
        emulator_model_no = last(keys(model_initial_times))
        system = get_system(get_models(sim).emulation_model)
        ini_time, ts_length = PSY.check_time_series_consistency(sys, PSY.SingleTimeSeries)
        resolution = PSY.get_time_series_resolution(system)
        em_available_times = range(ini_time, step = resolution, length = ts_length)
        if get_initial_time(sim) ∉ em_available_times
            throw(
                IS.ConflictingInputsError(
                    "The simulation initial_time $sim_ini_time isn't contained in the
                    emulation model $(get_name(em)).",
                ),
            )
        else
            model_initial_times[emulator_model_no + 1] = sim.initial_time
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
        get_execution_count(model)
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Problem $(get_name(model))" begin
            build_impl!(model)
        end
        sim.internal.date_ref[model_number] = initial_time
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

function _initialize_problem_storage!(
    sim::Simulation,
    cache_size_mib,
    min_cache_flush_size_mib,
)
    sequence = get_sequence(sim)
    executions_by_model = sequence.executions_by_model
    models = get_models(sim)
    model_store_params = OrderedDict{Symbol, ModelStoreParams}()
    model_req = Dict{Symbol, SimulationModelStoreRequirements}()
    num_param_containers = 0
    rules = CacheFlushRules(
        max_size = cache_size_mib * MiB,
        min_flush_size = min_cache_flush_size_mib,
    )
    for model in get_decision_models(models)
        model_name = get_name(model)
        model_store_params[model_name] = model.internal.store_parameters
        horizon = get_horizon(model)
        num_executions = executions_by_model[model_name]
        reqs = SimulationModelStoreRequirements()
        container = get_optimization_container(model)
        num_rows = num_executions * get_steps(sim)

        # TODO: configuration of keep_in_cache and priority are not correct

        for (key, array) in get_duals(container)
            reqs.duals[model] = _calc_dimensions(array, encode_key(key), num_rows, horizon)
            add_rule!(rules, model_name, key, false, CachePriority.LOW)
        end

        for (key, param_container) in get_parameters(container)
            array = get_parameter_array(param_container)
            reqs.parameters[key] =
                _calc_dimensions(array, encode_key(key), num_rows, horizon)
            add_rule!(rules, model_name, key, false, CachePriority.LOW)
        end

        for (key, array) in get_variables(container)
            reqs.variables[key] =
                _calc_dimensions(array, encode_key(key), num_rows, horizon)
            add_rule!(rules, model_name, key, false, CachePriority.HIGH)
        end

        for (key, array) in get_aux_variables(container)
            reqs.aux_variables[key] =
                _calc_dimensions(array, encode_key(key), num_rows, horizon)
            add_rule!(rules, model_name, key, false, CachePriority.HIGH)
        end

        # TODO: Do for expressions
        #for (key, array) in get_expressions(model)
        #    reqs.aux_variables[key] =
        #        _calc_dimensions(array, encode_key(key), num_rows, horizon)
        #    add_rule!(
        #        rules,
        #        model_name,
        #        key,
        #        false,
        #        CachePriority.HIGH,
        #    )
        #end

        model_req[model_name] = reqs

        num_param_containers +=
            length(reqs.duals) +
            length(reqs.parameters) +
            length(reqs.variables) +
            length(reqs.aux_variables) +
            length(reqs.expressions)
    end

    simulation_store_params = SimulationStoreParams(
        get_initial_time(sim),
        get_step_resolution(sequence),
        get_steps(sim),
        model_store_params,
    )
    @debug "initialized problem requirements" simulation_store_params
    store = get_simulation_store(sim)
    initialize_problem_storage!(store, simulation_store_params, model_req, rules)
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
        set_executions!(em, Int(step_resolution / em_resolution))
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
    output_dir = nothing,
    recorders = [],
    console_level = Logging.Error,
    file_level = Logging.Info,
    serialize = true,
    initialize_problem = false,
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

function _apply_warm_start!(model::DecisionModel)
    container = get_optimization_container(model)
    jump_model = get_jump_model(container)
    all_vars = JuMP.all_variables(jump_model)
    all_vars_value = JuMP.value.(all_vars)
    JuMP.set_start_value.(all_vars, all_vars_value)
    return
end

function _update_simulation_state!(sim::Simulation, model::DecisionModel)
    model_name = get_name(model)
    store = get_simulation_store(sim)
    simulation_time = get_current_time(sim)
    state = get_simulation_state(sim)
    for field in fieldnames(StateInfo)
        model_params = get_model_params(store, model_name)
        for key in list_fields(store, model_name, field)
            state_info = getfield(state.decision_states, field)
            # TODO: Read Array here to avoid allocating the DataFrame
            res = read_result(DataFrames.DataFrame, store, model_name, key, simulation_time)
            end_of_step_timestamp = get_end_of_step_timestamp(state)
            update_state_data!(
                state_info[key],
                # TODO: Pass Array{Float64} here to avoid allocating the DataFrame
                res,
                simulation_time,
                model_params,
                end_of_step_timestamp,
            )
            IS.@record :execution StateUpdateEvent(
                key,
                simulation_time,
                model_name,
                "DecisionState",
            )
        end
    end
end

function _set_system_state!(sim::Simulation)
    # TODO: Update after solution of emulation
    # em = get_emulation_model(get_models(sim))
    sim_state = get_simulation_state(sim)
    system_state = get_system_state(sim_state)
    decision_state = get_decision_states(sim_state)
    simulation_time = get_current_time(sim)

    for field in fieldnames(StateInfo)
        system_state_field = getfield(system_state, field)
        decision_field = getfield(decision_state, field)
        for (key, data) in decision_field
            if get_last_update_timestamp(decision_field[key]) == simulation_time
                get_state_values(system_state_field[key])[1, :] .=
                    DataFrames.values(get_state_values(data)[1, :])
            elseif get_last_update_timestamp(decision_field[key]) < simulation_time
                get_state_values(system_state_field[key])[1, :] .=
                    DataFrames.values(get_state_value(data, simulation_time))
            elseif get_last_update_timestamp(decision_field[key]) > simulation_time
                error("Something went really wrong. Please report this error.")
            end
            # IS.@record :execution StateUpdateEvent(
            #    key,
            #    simulation_time,
            #    model_name,
            #    "EmulationState",
            #)
        end
    end

    return
end

""" Default problem update function for most problems with no customization"""
function update_model!(
    model::DecisionModel{M},
    sim::Simulation,
) where {M <: DecisionProblem}
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
    cache_size_mib = 1024,
    min_cache_flush_size_mib = MIN_CACHE_FLUSH_SIZE_MiB,
    exports = nothing,
    enable_progress_bar = progress_meter_enabled(),
    disable_timer_outputs = false,
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

    prog_bar = ProgressMeter.Progress(num_executions; enabled = enable_progress_bar)
    disable_timer_outputs && TimerOutputs.disable_timer!(RUN_SIMULATION_TIMER)
    store = get_simulation_store(sim)
    for step in 1:steps
        IS.@record :simulation_status SimulationStepEvent(
            get_current_time(sim),
            step,
            "start",
        )
        for (ix, model_number) in enumerate(execution_order)
            IS.@record :simulation_status ProblemExecutionEvent(
                get_current_time(sim),
                step,
                model_number,
                "start",
            )
            model = get_decision_models(models)[model_number]
            model_name = get_name(model)
            TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execute $(model_name)" begin
                if !is_built(model)
                    error("$(model_name) status is not BuildStatus.BUILT")
                end
                problem_interval = get_interval(sequence, model_name)
                set_current_time!(sim, sim.internal.date_ref[model_number])
                sequence.current_execution_index = ix

                # Is first run of first problem? Yes -> don't update problem

                TimerOutputs.@timeit RUN_SIMULATION_TIMER "Update $(model_name)" begin
                    !(step == 1 && ix == 1) && update_model!(model, sim)
                end

                TimerOutputs.@timeit RUN_SIMULATION_TIMER "Solve $(model_name)" begin
                    settings = get_settings(model)
                    status =
                        solve!(step, model, get_current_time(sim), store; exports = exports)
                    if get_allow_fails(settings) && (status != RunStatus.SUCCESSFUL)
                        continue
                    elseif !get_allow_fails(settings) && (status != RunStatus.SUCCESSFUL)
                        throw(
                            ErrorException(
                                "Simulation Failed in problem $(model_name). Returned $(status)",
                            ),
                        )
                    else
                        @assert status == RunStatus.SUCCESSFUL
                    end
                end # Run problem Timer

                TimerOutputs.@timeit RUN_SIMULATION_TIMER "Update State" begin
                    _update_simulation_state!(sim, model)
                    _set_system_state!(sim)
                end
                global_problem_execution_count = (step - 1) * length(execution_order) + ix
                sim.internal.run_count[step][model_number] += 1
                sim.internal.date_ref[model_number] += problem_interval

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
                    model_number,
                    "done",
                )

                ProgressMeter.update!(
                    prog_bar,
                    global_problem_execution_count;
                    showvalues = [
                        (:Step, step),
                        (:model, model_name),
                        (:("Simulation Timestamp"), get_current_time(sim)),
                    ],
                )
            end #execution problem timer
        end # execution order for loop

        IS.@record :simulation_status SimulationStepEvent(
            get_current_time(sim),
            step,
            "done",
        )
    end # Steps for loop
    return nothing
end

"""
    execute!(sim::Simulation; kwargs...)

Solves the simulation model for sequential Simulations.

# Arguments
- `sim::Simulation=sim`: simulation object created by Simulation()

The optional keyword argument `exports` controls exporting of results to CSV files as
the simulation runs. Refer to [`export_results`](@ref) for a description of this argument.

# Example
```julia
sim = Simulation("Test", 7, problems, "/Users/folder")
execute!(sim::Simulation; kwargs...)
```
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
        open_store(store_type, get_store_dir(sim), "w") do store
            set_simulation_store!(sim, store)
            # TODO: return file name for hash calculation instead of hard code
            Logging.with_logger(logger) do
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
function serialize_simulation(sim::Simulation; path = nothing, force = false)
    if path === nothing
        directory = get_simulation_files_dir(sim)
    else
        directory = path
    end
    problems = get_model_names(get_models(sim))

    orig = pwd()
    if !isempty(readdir(directory)) && !force
        throw(
            ArgumentError(
                "$directory has files already: $(readdir(directory)). Please delete them or pass force = true.",
            ),
        )
    end
    rm(directory, recursive = true, force = true)
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
                        optimizer = problem_info[key]["optimizer"],
                    ),
                    get(problem_info[key], "jump_model", nothing),
                ),
            )
        end

        sim = Simulation(;
            name = obj.name,
            steps = obj.steps,
            models = SimulationModels(problems...),
            problems_sequence = obj.sequence,
            simulation_folder = obj.simulation_folder,
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
