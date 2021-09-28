# Default disable of progress bar when the simulation environment is an HPC or CI
const _PROGRESS_METER_ENABLED =
    !(isa(stderr, Base.TTY) == false || (get(ENV, "CI", nothing) == "true"))

const RESULTS_DIR = "results"

mutable struct SimulationInternal
    sim_files_dir::String
    store_dir::String
    logs_dir::String
    models_dir::String
    recorder_dir::String
    results_dir::String
    run_count::Dict{Int, Dict{Int, Int}}
    date_ref::Dict{Int, Dates.DateTime}
    current_time::Dates.DateTime
    status::Union{Nothing, RunStatus}
    build_status::BuildStatus
    simulation_cache::Dict{<:CacheKey, AbstractCache}
    store::Union{Nothing, SimulationStore}
    recorders::Vector{Symbol}
    console_level::Base.CoreLogging.LogLevel
    file_level::Base.CoreLogging.LogLevel
end

function SimulationInternal(
    steps::Int,
    model_count::Int,
    sim_dir,
    name;
    output_dir = nothing,
    recorders = [],
    console_level = Logging.Error,
    file_level = Logging.Info,
)
    count_dict = Dict{Int, Dict{Int, Int}}()

    for s in 1:steps
        count_dict[s] = Dict{Int, Int}()
        for st in 1:model_count
            count_dict[s][st] = 0
        end
    end

    base_dir = joinpath(sim_dir, name)
    mkpath(base_dir)

    output_dir = _get_output_dir_name(base_dir, output_dir)
    simulation_dir = joinpath(base_dir, output_dir)
    if isdir(simulation_dir)
        error("$simulation_dir already exists. Delete it or pass a different output_dir.")
    end

    sim_files_dir = joinpath(simulation_dir, "simulation_files")
    store_dir = joinpath(simulation_dir, "data_store")
    logs_dir = joinpath(simulation_dir, "logs")
    models_dir = joinpath(simulation_dir, "problems")
    recorder_dir = joinpath(simulation_dir, "recorder")
    results_dir = joinpath(simulation_dir, RESULTS_DIR)

    for path in (
        simulation_dir,
        sim_files_dir,
        logs_dir,
        models_dir,
        recorder_dir,
        results_dir,
        store_dir,
    )
        mkpath(path)
    end

    unique_recorders = Set(REQUIRED_RECORDERS)
    foreach(x -> push!(unique_recorders, x), recorders)

    init_time = Dates.now()
    return SimulationInternal(
        sim_files_dir,
        store_dir,
        logs_dir,
        models_dir,
        recorder_dir,
        results_dir,
        count_dict,
        Dict{Int, Dates.DateTime}(),
        init_time,
        nothing,
        BuildStatus.EMPTY,
        Dict{CacheKey, AbstractCache}(),
        nothing,
        collect(unique_recorders),
        console_level,
        file_level,
    )
end

function configure_logging(internal::SimulationInternal, file_mode)
    return IS.configure_logging(
        console = true,
        console_stream = stderr,
        console_level = internal.console_level,
        file = true,
        filename = joinpath(internal.logs_dir, SIMULATION_LOG_FILENAME),
        file_level = internal.file_level,
        file_mode = file_mode,
        tracker = nothing,
        set_global = false,
    )
end

function register_recorders!(internal::SimulationInternal, file_mode)
    for name in internal.recorders
        IS.register_recorder!(name; mode = file_mode, directory = internal.recorder_dir)
    end
end

function unregister_recorders!(internal::SimulationInternal)
    for name in internal.recorders
        IS.unregister_recorder!(name)
    end
end

function _add_initial_condition_caches(
    sim::SimulationInternal,
    model::DecisionModel,
    caches::Union{Nothing, Vector{<:AbstractCache}},
)
    for (ic_key, init_conds) in get_initial_conditions(get_optimization_container(model))
        _create_cache(ic_key, caches)
    end
    return
end

function _create_cache(ic_key::ICKey, caches::Union{Nothing, Vector{<:AbstractCache}})
    return
end

function _create_cache(
    ic_key::ICKey{InitialTimeDurationOn, T},
    caches::Union{Nothing, Vector{<:AbstractCache}},
) where {T <: PSY.Device}
    cache_keys = CacheKey.(caches)
    if isempty(cache_keys) || !in(CacheKey(TimeStatusChange, T), cache_keys)
        cache = TimeStatusChange(T, OnVariable())
        push!(caches, cache)
    end
    return
end

function _create_cache(
    ic_key::ICKey{InitialTimeDurationOff, T},
    caches::Vector{<:AbstractCache},
) where {T <: PSY.Device}
    cache_keys = CacheKey.(caches)
    if isempty(cache_keys) || !in(CacheKey(TimeStatusChange, T), cache_keys)
        cache = TimeStatusChange(T, OnVariable)
        push!(caches, cache)
    end
    return
end

function _create_cache(
    ic_key::ICKey{InitialEnergyLevel, T},
    caches::Vector{<:AbstractCache},
) where {T <: PSY.Device}
    cache_keys = CacheKey.(caches)
    if isempty(cache_keys) || !in(CacheKey(StoredEnergy, T), cache_keys)
        cache = StoredEnergy(T, EnergyVariable)
        push!(caches, cache)
    end
    return
end

function _set_internal_caches(
    internal::SimulationInternal,
    model::DecisionModel,
    caches::Vector{<:AbstractCache},
)
    for c in caches
        cache_key = CacheKey(c)
        caches = get_caches(model)
        push!(caches, cache_key)
        if !haskey(internal.simulation_cache, cache_key)
            @debug "Cache $(cache_key) added to the simulation"
            internal.simulation_cache[cache_key] = c
        end
        internal.simulation_cache[cache_key].value = get_initial_cache(c, model)
    end
    return
end

function _get_output_dir_name(path, output_dir)
    if !(output_dir === nothing)
        # The user wants a custom name.
        return output_dir
    end

    # Return the next highest integer.
    output_dir = 1
    for name in readdir(path)
        if occursin(r"^\d+$", name)
            num = parse(Int, name)
            if num >= output_dir
                output_dir = num + 1
            end
        end
    end

    return string(output_dir)
end

# TODO: Add DocString
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
# TODO DT: this description is probably wrong
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

function check_chronology!(sim::Simulation, key::Pair, sync::Synchronize)
    source_model = get_model(sim, key.first)
    source_model_horizon = get_horizon(source_model)
    sequence = get_sequence(sim)
    destination_model_interval = get_interval(sequence, key.second)

    source_model_resolution = get_resolution(source_model)
    @debug source_model_resolution, destination_model_interval
    # How many times the second model executes per solution retireved from the source_model.
    # E.g. source_model_resolution = 1 Hour, destination_model_interval = 5 minutes => 12 executions per solution
    destination_model_executions_per_solution =
        Int(source_model_resolution / destination_model_interval)
    # Number of periods in the horizon that will be synchronized between the source_model and the destination_model
    source_model_sync = sync.periods

    if source_model_sync > source_model_horizon
        throw(
            IS.ConflictingInputsError(
                "The lookahead length $(source_model_horizon) in model is insufficient to syncronize with $(source_model_sync) feedforward periods",
            ),
        )
    end

    if (source_model_sync % destination_model_executions_per_solution) != 0
        throw(
            IS.ConflictingInputsError(
                "The current configuration implies $(source_model_sync / destination_model_executions_per_solution) executions of $(key.second) per execution of $(key.first). The number of Synchronize periods $(sync.periods) in model $(key.first) needs to be a mutiple of the number of model $(key.second) execution for every model $(key.first) interval.",
            ),
        )
    end

    return
end

function check_chronology!(sim::Simulation, key::Pair, ::Consecutive)
    source_model = get_model(sim, key.first)
    source_model_horizon = get_horizon(source_model)
    if source_model_horizon != source_model_interval
        @warn(
            "Consecutive Chronology Requires the same interval and horizon, the parameter horizon = $(source_model_horizon) in model $(key.first) will be replaced with $(source_model_interval). If this is not the desired behviour consider changing your chronology to RecedingHorizon"
        )
    end
    get_sequence(sim).horizons[key.first] = get_interval(sim, key.first)
    return
end

check_chronology!(sim::Simulation, key::Pair, ::RecedingHorizon) = nothing
check_chronology!(sim::Simulation, key::Pair, ::FullHorizon) = nothing
# TODO: Add missing check
check_chronology!(sim::Simulation, key::Pair, ::Range) = nothing

function check_chronology!(
    sim::Simulation,
    key::Pair,
    ::T,
) where {T <: FeedForwardChronology}
    error("Chronology $(T) not implemented")
    return
end

function get_model_cache_definition(sim::Simulation, model::Symbol)
    caches = get_sequence(sim).cache
    cache_ref = Array{AbstractCache, 1}()
    for model_names in keys(caches)
        if model in model_names
            push!(cache_ref, caches[model_names])
        end
    end
    return cache_ref
end

function get_cache(simulation_cache::Dict{<:CacheKey, AbstractCache}, key::CacheKey)
    c = get(simulation_cache, key, nothing)
    c === nothing && @debug("Cache with key $(key) not present in the simulation")
    return c
end

function get_cache(
    simulation_cache::Dict{<:CacheKey, AbstractCache},
    ::Type{T},
    ::Type{D},
) where {T <: AbstractCache, D <: PSY.Device}
    return get_cache(simulation_cache, CacheKey(T, D))
end

function get_cache(
    sim::Simulation,
    ::Type{T},
    ::Type{D},
) where {T <: AbstractCache, D <: PSY.Device}
    return get_cache(sim.internal.simulation_cache, CacheKey(T, D))
end

function _check_forecasts_sequence(sim::Simulation)
    for model in get_models(sim)
        sequence = get_sequence(sim)
        resolution = get_resolution(model)
        horizon = get_horizon(model)
        # JDNOTE: To be refactored when fixing interval in sequence
        interval = get_interval(sequence, get_name(model))
        horizon_time = resolution * horizon
        if horizon_time < interval
            throw(IS.ConflictingInputsError("horizon ($horizon_time) is
                                shorter than interval ($interval) for $(get_name(model))"))
        end
    end
end

function _check_feedforward_chronologies(sim::Simulation)
    for (key, chron) in get_sequence(sim).feedforward_chronologies
        check_chronology!(sim, key, chron)
    end
    return
end

function _assign_feedforward_chronologies(sim::Simulation)
    sequence = get_sequence(sim)
    # JDNOTE: this is limiting since it only allows updating from one problem
    for (key, chron) in get_sequence(sim).feedforward_chronologies
        destination_model = get_model(sim, key.second)
        destination_model_interval_ = get_interval(sequence, key.second)
        destination_model_interval = IS.time_period_conversion(destination_model_interval_)
        source_model = get_model(sim, key.first)
        source_model_number = get_simulation_number(source_model)
        sim_info = get_simulation_info(destination_model)
        sim_info.chronolgy_dict[source_model_number] = chron
        source_model_resolution_ = PSY.get_time_series_resolution(source_model.sys)
        source_model_resolution = IS.time_period_conversion(source_model_resolution_)
        execution_wait_count = Int(source_model_resolution / destination_model_interval)
        set_execution_wait_count!(get_trigger(chron), execution_wait_count)
        initialize_trigger_count!(get_trigger(chron))
    end
    return
end

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

function _attach_feedforward!(sim::Simulation, model_name::Symbol)
    model = get_model(sim, model_name)
    # JDNOTES: making a conversion here isn't great. Needs refactor
    feedforward = filter(p -> (p.first == model_name), get_sequence(sim).feedforward)
    for (key, ff) in feedforward
        device_model = get_model(model.template, get_component_type(ff))
        device_model === nothing && throw(
            IS.ConflictingInputsError("Device model $key not found in model $model_name"),
        )
        attach_feedforward(device_model, ff)
    end
    return
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

function _check_required_ini_cond_caches(sim::Simulation)
    for model in get_models(sim)
        container = get_optimization_container(model)
        for (k, v) in iterate_initial_conditions(container)
            # No cache needed for the initial condition -> continue
            v[1].cache_type === nothing && continue
            c = get_cache(sim, v[1].cache_type, get_component_type(k))
            if c === nothing
                throw(
                    ArgumentError(
                        "Cache $(v[1].cache_type) not defined for initial condition $(k) in problem $(get_name(model))",
                    ),
                )
            end
            @debug "found cache $(v[1].cache_type) for initial condition $(k) in problem $(get_name(model))"
        end
    end
    return
end

function _populate_caches!(sim::Simulation, model_name::Symbol)
    caches = get_model_cache_definition(sim, model_name)
    model = get_model(sim, model_name)
    # JDNOTES: Why passing here the internal and not the simulation cache ?
    _add_initial_condition_caches(sim.internal, model, caches)
    _set_internal_caches(sim.internal, model, caches)
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
        problem_chronology = get_problem_interval_chronology(get_sequence(sim), name)
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
    _check_required_ini_cond_caches(sim)
    return
end

function _build!(sim::Simulation, serialize::Bool)
    set_simulation_build_status!(sim, BuildStatus.IN_PROGRESS)
    problem_initial_times = _get_simulation_initial_times!(sim)
    sequence = get_sequence(sim)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Assign FeedForward" begin
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
            _attach_feedforward!(sim, name)
        end
        _assign_feedforward_chronologies(sim)
    end
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Check Steps" begin
        _check_steps(sim, problem_initial_times)
    end
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build Problems" begin
        _build_problems!(sim, serialize)
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
            _check_forecasts_sequence(sim)
            _check_feedforward_chronologies(sim)
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

# Defined here because it requires problem and Simulation to defined

############################# Interfacing Functions ##########################################
# These are the functions that the user will have to implement to update a custom IC Chron #
# or custom InitialConditionType #

""" Updates the initial conditions of the problem"""
function initial_condition_update!(
    model::DecisionModel,
    ini_cond_key::ICKey,
    initial_conditions::Vector{InitialCondition},
    ::IntraProblemChronology,
    sim::Simulation,
)
    # TODO: Replace this convoluted way to get information with access to data store
    execution_count = get_execution_count(problem)
    execution_count == 0 && return
    simulation_cache = sim.internal.simulation_cache
    for ic in initial_conditions
        name = get_component_name(ic)
        interval_chronology = get_model_interval_chronology(sim.sequence, get_name(model))
        var_value = get_model_variable(
            interval_chronology,
            (problem => problem),
            name,
            ic.update_ref,
        )
        # We pass the simulation cache instead of the whole simulation to avoid definition dependencies.
        # All the inputs to calculate_ic_quantity are defined before the simulation object
        quantity = calculate_ic_quantity(
            ini_cond_key,
            ic,
            var_value,
            simulation_cache,
            get_resolution(model),
        )
        previous_value = get_condition(ic)
        PJ.set_value(ic.value, quantity)
        IS.@record :simulation InitialConditionUpdateEvent(
            get_current_time(sim),
            ini_cond_key,
            ic,
            quantity,
            previous_value,
            get_simulation_number(model),
        )
    end
end

""" Updates the initial conditions of the problem"""
function initial_condition_update!(
    model::DecisionModel,
    ini_cond_key::ICKey,
    initial_conditions::Vector{InitialCondition},
    ::InterProblemChronology,
    sim::Simulation,
)
    # TODO: Replace this convoluted way to get information with access to data store
    simulation_cache = sim.internal.simulation_cache
    execution_index = get_execution_order(sim)
    execution_count = get_execution_count(model)
    model_name = get_name(model)
    sequence = get_sequence(sim)
    interval = get_interval(sequence, model_name)
    for ic in initial_conditions
        name = get_component_name(ic)
        current_ix = get_current_execution_index(sim)
        source_model_ix = current_ix == 1 ? last(execution_index) : current_ix - 1
        source_model = get_model(sim, execution_index[source_model_ix])
        source_model_name = get_name(source_model)

        # If the model that ran before is lower in the order of execution the chronology needs to grab the first result as the initial condition
        if get_simulation_number(source_model) >= get_simulation_number(model)
            interval_chronology = get_model_interval_chronology(sequence, source_model_name)
        elseif get_simulation_number(source_model) < get_simulation_number(model)
            interval_chronology = RecedingHorizon()
        end
        var_value = get_model_variable(
            interval_chronology,
            (source_model => model),
            model_name,
            ic.update_ref,
        )
        quantity =
            calculate_ic_quantity(ini_cond_key, ic, var_value, simulation_cache, interval)
        previous_value = get_condition(ic)
        PJ.set_value(ic.value, quantity)
        IS.@record :simulation InitialConditionUpdateEvent(
            get_current_time(sim),
            ini_cond_key,
            ic,
            quantity,
            previous_value,
            get_simulation_number(model),
        )
    end
    return
end

function _update_caches!(sim::Simulation, model::DecisionModel)
    for cache in get_caches(model)
        update_cache!(sim, cache, model)
    end
    return
end

################################ Cache Update ################################################
# TODO: Need to be careful here if 2 problems modify the same cache. This function might need
# dispatch on the Statge{OpModel} to assign different actions. e.g. HAUC and DAUC
function update_cache!(
    sim::Simulation,
    ::CacheKey{TimeStatusChange, D},
    model::DecisionModel,
) where {D <: PSY.Device}
    # TODO: Remove debug statements and use recorder here
    c = get_cache(sim, TimeStatusChange, D)
    increment = get_increment(sim, model, c)
    variable = get_variable(model.internal.container, c.ref)
    t_range = 1:get_end_of_interval_step(model)
    for name in variable.axes[1]
        # Store the initial condition
        c.value[name][:series] = Vector{Float64}(undef, length(t_range) + 1)
        c.value[name][:series][1] = c.value[name][:status]
        c.value[name][:current] = 1
        c.value[name][:elapsed] = Dates.Second(0)
        for t in t_range
            # Implemented this way because JuMPDenseAxisArrays doesn't support pasing a ranges Array[name, 1:n]
            device_status = JuMP.value.(variable[name, t])
            c.value[name][:series][t + 1] = device_status
            if c.value[name][:status] == device_status
                c.value[name][:count] += increment
                @debug(
                    "Cache value TimeStatus for device $name set to $device_status and count to $(c.value[name][:count])"
                )
            else
                c.value[name][:count] = increment
                c.value[name][:status] = device_status
                @debug(
                    "Cache value TimeStatus for device $name set to $device_status and count to 1.0"
                )
            end
        end
    end

    return
end

function get_increment(sim::Simulation, model::DecisionModel, cache::TimeStatusChange)
    units = cache.units
    name = get_name(model)
    sequence = get_sequence(sim)
    interval = get_interval(sequence, name)
    resolution = interval / units
    return resolution
end

function update_cache!(
    sim::Simulation,
    ::CacheKey{StoredEnergy, D},
    model::DecisionModel,
) where {D <: PSY.Device}
    c = get_cache(sim, StoredEnergy, D)
    variable = get_variable(model.internal.container, c.ref)
    t = get_end_of_interval_step(model)
    for name in variable.axes[1]
        device_energy = JuMP.value(variable[name, t])
        @debug name, device_energy
        c.value[name] = device_energy
        @debug("Cache value StoredEnergy for device $name set to $(c.value[name])")
    end

    return
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
    enable_progress_bar = _PROGRESS_METER_ENABLED,
    disable_timer_outputs = false,
)
    @assert !isnothing(sim.internal)

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

function _calc_dimensions(array::JuMP.Containers.DenseAxisArray, name, num_rows, horizon)
    ax = axes(array)
    # Two use cases for read:
    # 1. Read data for one execution for one device.
    # 2. Read data for one execution for all devices.
    # This will ensure that data on disk is contiguous in both cases.
    if length(ax) == 1
        columns = [name]
        dims = (horizon, 1, num_rows)
    elseif length(ax) == 2
        columns = collect(axes(array)[1])
        dims = (horizon, length(columns), num_rows)
        # elseif length(ax) == 3
        #     # TODO: untested
        #     dims = (length(ax[2]), horizon, length(columns), num_rows)
    else
        error("unsupported data size $(length(ax))")
    end

    return Dict("columns" => columns, "dims" => dims)
end

function _calc_dimensions(array::JuMP.Containers.SparseAxisArray, name, num_rows, horizon)
    columns = unique([(k[1], k[3]) for k in keys(array.data)])
    dims = (horizon, length(columns), num_rows)
    return Dict("columns" => columns, "dims" => dims)
end

struct SimulationSerializationWrapper
    steps::Int
    problems::Vector{Symbol}
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
