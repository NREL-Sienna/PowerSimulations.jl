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
        for model in models
            model_name = get_name(model)
            if !built_for_recurrent_solves(model)
                throw(
                    IS.ConflictingInputsError(
                        "model $(model_name) is not part of any Simulation",
                    ),
                )
            end
            if model.internal.simulation_info.sequence_uuid != sequence.uuid
                throw(
                    IS.ConflictingInputsError(
                        "The model definition for $model_name doesn't correspond to the simulation sequence",
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

################# accessor functions ####################
get_initial_time(sim::Simulation) = sim.initial_time
get_sequence(sim::Simulation) = sim.sequence
get_steps(sim::Simulation) = sim.steps
get_current_time(sim::Simulation) = sim.internal.current_time
get_models(sim::Simulation) = sim.models
get_model(sim::Simulation, ix::Int) = sim.models[ix]
get_model(sim::Simulation, name::Symbol) = get_model(sim.models, name)
get_simulation_dir(sim::Simulation) = dirname(sim.internal.logs_dir)
get_simulation_files_dir(sim::Simulation) = sim.internal.sim_files_dir
get_store_dir(sim::Simulation) = sim.internal.store_dir
get_simulation_status(sim::Simulation) = sim.internal.status
get_simulation_build_status(sim::Simulation) = sim.internal.build_status
set_simulation_store!(sim::Simulation, store) = sim.internal.store = store
get_simulation_store(sim::Simulation) = sim.internal.store
get_results_dir(sim::Simulation) = sim.internal.results_dir
get_models_dir(sim::Simulation) = sim.internal.models_dir

function get_base_powers(sim::Simulation)
    base_powers = Dict()
    for model in get_models(sim)
        base_powers[get_name(model)] = PSY.get_base_power(get_system(model))
    end
    return base_powers
end

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
set_current_time!(sim::Simulation, val) = sim.internal.current_time = val

function _get_simulation_initial_times!(sim::Simulation)
    model_initial_times = Dict{Int, Vector{Dates.DateTime}}()
    sim_ini_time = get_initial_time(sim)
    for (model_number, model) in enumerate(get_models(sim))
        system = get_system(model)
        system_interval = PSY.get_forecast_interval(system)
        model_interval = get_interval(get_sequence(sim), get_name(model))
        if system_interval != model_interval
            throw(
                IS.ConflictingInputsError(
                    "Simulation interval ($model_interval) and forecast interval ($system_interval) definitions are not compatible",
                ),
            )
        end
        model_horizon = get_horizon(model)
        system_horizon = PSY.get_forecast_horizon(system)
        if model_horizon > system_horizon
            throw(
                IS.ConflictingInputsError(
                    "Simulation horizon ($model_horizon) and forecast horizon ($system_horizon) definitions are not compatible",
                ),
            )
        end
        model_initial_times[model_number] = PSY.get_forecast_initial_times(system)
        for (ix, element) in enumerate(model_initial_times[model_number][1:(end - 1)])
            if !(element + system_interval == model_initial_times[model_number][ix + 1])
                throw(IS.ConflictingInputsError("The sequence of forecasts is invalid"))
            end
        end
        if !(sim_ini_time === nothing) &&
           !mapreduce(x -> x == sim_ini_time, |, model_initial_times[model_number])
            throw(
                IS.ConflictingInputsError(
                    "The specified simulation initial_time $sim_ini_time isn't contained in model $model_number.
Manually provided initial times have to be compatible with the specified interval and horizon in the models.",
                ),
            )
        end
    end
    if get_initial_time(sim) === nothing
        sim.initial_time = model_initial_times[1][1]
        @debug("Initial Simulation Time will be infered from the data.
               Initial Simulation Time set to $(sim.initial_time)")
    end

    sim.internal.current_time = sim.initial_time
    return model_initial_times
end

function _check_steps(
    sim::Simulation,
    model_initial_times::Dict{Int, Vector{Dates.DateTime}},
)
    sequence = get_sequence(sim)
    execution_order = get_execution_order(sequence)
    for (model_number, model) in enumerate(get_models(sim))
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

function _build_problems!(sim::Simulation, serialize)
    for (model_number, model) in enumerate(get_models(sim))
        name = get_name(model)
        @info("Building problem $(model_number)-$(name)")
        initial_time = get_initial_time(sim)
        set_initial_time!(model, initial_time)
        output_dir = joinpath(get_models_dir(sim))
        set_output_dir!(model, output_dir)
        initialize_simulation_info!(model, problem_chronology)
        problem_build_status = _build!(model, serialize)
        if problem_build_status != BuildStatus.BUILT
            error("Problem $(name) failed to build succesfully")
        end
        _populate_caches!(sim, name)
        sim.internal.date_ref[model_number] = initial_time
    end
    return
end

function _build!(sim::Simulation, serialize::Bool)
    set_simulation_build_status!(sim, BuildStatus.IN_PROGRESS)
    problem_initial_times = _get_simulation_initial_times!(sim)
    sequence = get_sequence(sim)
    for (ix, model) in enumerate(get_models(sim))
        name = get_name(model)
        problem_interval = get_interval(sequence, name)
        # Note to devs: Here we are setting the number of operations problem executions we
        # will see for every step of the simulation
        if ix == 1
            set_executions!(model, 1)
        else
            step_resolution = get_step_resolution(sequence)
            set_executions!(model, Int(step_resolution / problem_interval))
        end
    end
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Check Steps" begin
        _check_steps(sim, problem_initial_times)
    end
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build Problems" begin
        _build_problems!(sim, serialize)
        # Make EmulationModel
        # Make SimulationState here
    end
    if serialize
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Serializing Simulation Files" begin
            serialize_simulation(sim)
        end
    end
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
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Initialize Simulation" begin
            _check_folder(sim)
            sim.internal = SimulationInternal(
                sim.steps,
                length(get_models(sim)),
                get_simulation_folder(sim),
                get_name(sim);
                output_dir = output_dir,
                recorders = recorders,
                console_level = console_level,
                file_level = file_level,
            )
        end
        file_mode = "w"
        logger = configure_logging(sim.internal, file_mode)
        register_recorders!(sim.internal, file_mode)
        try
            Logging.with_logger(logger) do
                _build!(sim, serialize)
                set_simulation_build_status!(sim, BuildStatus.BUILT)
                set_simulation_status!(sim, RunStatus.READY)
            end
        catch e
            set_simulation_build_status!(sim, BuildStatus.FAILED)
            set_simulation_status!(sim, nothing)
            rethrow(e)
        finally
            unregister_recorders!(sim.internal)
            close(logger)
        end
    end
    initialize_problem && _initial_conditions_problems!(sim)
    @info "\n$(BUILD_PROBLEMS_TIMER)\n"
    return get_simulation_build_status(sim)
end

function get_increment(sim::Simulation, model::DecisionModel, cache::TimeStatusChange)
    units = cache.units
    name = get_name(model)
    sequence = get_sequence(sim)
    interval = get_interval(sequence, name)
    resolution = interval / units
    return resolution
end

function _update_initial_conditions!(model::DecisionModel, sim::Simulation)
    ini_cond_chronology = get_sequence(sim).ini_cond_chronology
    optimization_containter = get_optimization_container(model)
    for (k, v) in iterate_initial_conditions(optimization_containter)
        initial_condition_update!(model, k, v, ini_cond_chronology, sim)
    end
    return
end

function _update_parameters(model::DecisionModel, sim::Simulation)
    container = get_optimization_container(model)
    for container in iterate_parameter_containers(container)
        update_parameter!(container.update_ref, container, model, sim)
    end
    return
end

function _apply_warm_start!(model::DecisionModel)
    container = get_optimization_container(model)
    jump_model = get_jump_model(container)
    all_vars = JuMP.all_variables(jump_model)
    JuMP.set_start_value.(all_vars, JuMP.value.(all_vars))
    return
end

""" Required update problem function call"""
function _update_problem!(model::DecisionModel, sim::Simulation)
    _update_parameters(model, sim)
    _update_initial_conditions!(model, sim)
    return
end

############################# Interfacing Functions##########################################
## These are the functions that the user will have to implement to update a custom problem ###
""" Generic problem update function for most problems with no customization"""
function update_problem!(
    model::DecisionModel{M},
    sim::Simulation,
) where {M <: DecisionProblem}  # DT This must remain problem
    _update_problem!(model, sim)
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
                TimerOutputs.reset_timer!(RUN_SIMULATION_TIMER)
                TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execute Simulation" begin
                    _execute!(sim; [k => v for (k, v) in kwargs if k != :in_memory]...)
                end
                @info ("\n$(RUN_SIMULATION_TIMER)\n")
                set_simulation_status!(sim, RunStatus.SUCCESSFUL)
                log_cache_hit_percentages(store)
            end
        end
    catch e
        # TODO: Add Fallback when run_problem fails
        set_simulation_status!(sim, RunStatus.FAILED)
        @error "simulation failed" exception = (e, catch_backtrace())
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
        TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execution Step $(step)" begin
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
                model = models[model_number]
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
                        !(step == 1 && ix == 1) && update_problem!(model, sim)
                    end
                    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Run $(model_name)" begin
                        settings = get_settings(model)
                        status = solve!(
                            step,
                            model,
                            get_current_time(sim),
                            store;
                            exports = exports,
                        )
                        global_problem_execution_count =
                            (step - 1) * length(execution_order) + ix
                        sim.internal.run_count[step][model_number] += 1
                        sim.internal.date_ref[model_number] += problem_interval
                        if get_allow_fails(settings) && (status != RunStatus.SUCCESSFUL)
                            continue
                        elseif !get_allow_fails(settings) &&
                               (status != RunStatus.SUCCESSFUL)
                            throw(
                                ErrorException(
                                    "Simulation Failed in problem $(model_name). Returned $(status)",
                                ),
                            )
                        else
                            @assert status == RunStatus.SUCCESSFUL
                        end
                    end # Run problem Timer
                    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Update Cache $(model_number)" begin
                        _update_caches!(sim, model)
                    end
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
        end # Execution step timer
    end # Steps for loop
    return nothing
end

function _initialize_problem_storage!(
    sim::Simulation,
    cache_size_mib,
    min_cache_flush_size_mib,
)
    sequence = get_sequence(sim)
    executions_by_problem = sequence.executions_by_problem
    intervals = sequence.intervals

    problems = OrderedDict{Symbol, ModelStoreParams}()
    problem_reqs = Dict{Symbol, SimulationStoreProblemRequirements}()
    num_param_containers = 0
    rules = CacheFlushRules(
        max_size = cache_size_mib * MiB,
        min_flush_size = min_cache_flush_size_mib,
    )
    for model in get_models(sim)
        model_name = get_name(model)
        reqs = SimulationStoreProblemRequirements()
        container = get_optimization_container(model)
        duals = get_duals(container)
        parameters = get_parameters(container)
        variables = get_variables(container)
        aux_variables = get_aux_variables(container)
        num_rows = num_executions * get_steps(sim)
        # TODO: configuration of keep_in_cache and priority are not correct
        for (key, array) in duals
            reqs.duals[model] = _calc_dimensions(array, encode_key(key), num_rows, horizon)
            add_rule!(
                rules,
                model_name,
                STORE_CONTAINER_DUALS,
                key,
                false,
                CachePriority.LOW,
            )
        end

        if parameters !== nothing
            for (key, param_container) in parameters
                # TODO JD: this needs improvement
                !isa(param_container.update_ref, UpdateRef{<:PSY.Component}) && continue
                array = get_parameter_array(param_container)
                reqs.parameters[key] =
                    _calc_dimensions(array, encode_key(key), num_rows, horizon)
                add_rule!(
                    rules,
                    Symbol(model_name),
                    STORE_CONTAINER_PARAMETERS,
                    key,
                    false,
                    CachePriority.LOW,
                )
            end
        end

        for (key, array) in variables
            reqs.variables[key] =
                _calc_dimensions(array, encode_key(key), num_rows, horizon)
            add_rule!(
                rules,
                model_name,
                STORE_CONTAINER_VARIABLES,
                key,
                false,
                CachePriority.HIGH,
            )
        end

        for (key, array) in aux_variables
            reqs.variables[key] =
                _calc_dimensions(array, encode_key(name), num_rows, horizon)
            add_rule!(
                rules,
                model_name,
                STORE_CONTAINER_VARIABLES,
                key,
                false,
                CachePriority.HIGH,
            )
        end

        problems[model_name] = problem_params
        problem_reqs[model_name] = reqs

        num_param_containers +=
            length(reqs.duals) + length(reqs.parameters) + length(reqs.variables)
    end

    store_params = SimulationStoreParams(
        get_initial_time(sim),
        sequence.step_resolution,
        get_steps(sim),
        problems,
    )
    @debug "initialized problem requirements" store_params
    store = get_simulation_store(sim)
    initialize_problem_storage!(store, store_params, problem_reqs, rules)
    return store_params
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
    for model in get_models(sim)
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
