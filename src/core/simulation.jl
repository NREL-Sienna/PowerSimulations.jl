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
    problem_count::Int,
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
        for st in 1:problem_count
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
    problem::OperationsProblem,
    caches::Union{Nothing, Vector{<:AbstractCache}},
)
    initial_conditions = problem.internal.optimization_container.initial_conditions
    for (ic_key, init_conds) in initial_conditions.data
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
        cache = TimeStatusChange(T, ON)
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
        cache = TimeStatusChange(T, ON)
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
        cache = StoredEnergy(T, ENERGY)
        push!(caches, cache)
    end
    return
end

function _create_cache(
    ic_key::ICKey{InitialEnergyLevel, T},
    caches::Vector{<:AbstractCache},
) where {T <: PSY.HybridSystem}
    cache_keys = CacheKey.(caches)
    if isempty(cache_keys) || !in(CacheKey(StoredEnergy, T), cache_keys)
        cache = StoredEnergy(T, SUBCOMPONENT_ENERGY)
        push!(caches, cache)
    end
    return
end

function _set_internal_caches(
    internal::SimulationInternal,
    problem::OperationsProblem,
    caches::Vector{<:AbstractCache},
)
    for c in caches
        cache_key = CacheKey(c)
        caches = get_caches(problem)
        push!(caches, cache_key)
        if !haskey(internal.simulation_cache, cache_key)
            @debug "Cache $(cache_key) added to the simulation"
            internal.simulation_cache[cache_key] = c
        end
        internal.simulation_cache[cache_key].value = get_initial_cache(c, problem)
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
@doc raw"""
    Simulation(steps::Int
                problems::Dict{String, OperationsProblem{<:AbstractOperationsProblem}}
                sequence::Union{Nothing, SimulationSequence}
                simulation_folder::String
                name::String
                internal::Union{Nothing, SimulationInternal}
                )

"""
mutable struct Simulation
    steps::Int
    problems::SimulationProblems
    initial_time::Union{Nothing, Dates.DateTime}
    sequence::SimulationSequence
    simulation_folder::String
    name::String
    internal::Union{Nothing, SimulationInternal}

    function Simulation(;
        sequence::SimulationSequence,
        name::String,
        steps::Int,
        problems::SimulationProblems,
        simulation_folder::String,
        initial_time = nothing,
    )
        for name in PSI.get_problem_names(problems)
            if !built_for_simulation(problems[name])
                throw(
                    IS.ConflictingInputsError(
                        "problem $(name) is not part of any Simulation",
                    ),
                )
            end
            if problems[name].internal.simulation_info.sequence_uuid != sequence.uuid
                throw(
                    IS.ConflictingInputsError(
                        "The Problem definition for $(name) doesn't correspond to the simulation sequence",
                    ),
                )
            end
        end
        new(steps, problems, initial_time, sequence, simulation_folder, name, nothing)
    end
end

"""
    Simulation(directory::AbstractString)

Constructs Simulation from a serialized directory. Callers should pass any kwargs here that
they passed to the original Simulation.

# Arguments
- `directory::AbstractString`: the directory returned from the call to serialize
- `problem_info::Dict`: Two-level dictionary containing problem parameters that cannot be
  serialized. The outer dict should be keyed by the problem name. The inner dict must contain
  'optimizer' and may contain 'jump_model'. These should be the same values used for the
  original simulation.
"""
function Simulation(directory::AbstractString, problem_info::Dict)
    obj = deserialize_model(Simulation, directory, problem_info)
end

################# accessor functions ####################
get_initial_time(sim::Simulation) = sim.initial_time
get_sequence(sim::Simulation) = sim.sequence
get_steps(sim::Simulation) = sim.steps
get_current_time(sim::Simulation) = sim.internal.current_time
get_problems(sim::Simulation) = sim.problems

function get_problem(sim::Simulation, ix::Int)
    problems = get_problems(sim)
    names = get_problem_names(problems)
    return problems[names[ix]]
end

function get_problem(sim::Simulation, name::Symbol)
    problems = get_problems(sim)
    return problems[name]
end

get_simulation_dir(sim::Simulation) = dirname(sim.internal.logs_dir)
get_simulation_files_dir(sim::Simulation) = sim.internal.sim_files_dir
get_store_dir(sim::Simulation) = sim.internal.store_dir
get_simulation_status(sim::Simulation) = sim.internal.status
get_simulation_build_status(sim::Simulation) = sim.internal.build_status
set_simulation_store!(sim::Simulation, store) = sim.internal.store = store
get_simulation_store(sim::Simulation) = sim.internal.store
get_results_dir(sim::Simulation) = sim.internal.results_dir
get_problems_dir(sim::Simulation) = sim.internal.models_dir

function get_base_powers(sim::Simulation)
    base_powers = Dict()
    for (name, problem) in get_problems(sim)
        base_powers[name] = PSY.get_base_power(get_system(problem))
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

function get_problem_cache_definition(sim::Simulation, problem::Symbol)
    caches = get_sequence(sim).cache
    cache_ref = Array{AbstractCache, 1}()
    for problem_names in keys(caches)
        if problem in problem_names
            push!(cache_ref, caches[problem_names])
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
    for (problem_number, (problem_name, problem)) in enumerate(sim.problems)
        sequence = get_sequence(sim)
        resolution = get_resolution(problem)
        horizon = get_horizon(problem)
        # JDNOTE: To be refactored when fixing interval in sequence
        interval = get_interval(sequence, problem_name)
        horizon_time = resolution * horizon
        if horizon_time < interval
            throw(IS.ConflictingInputsError("horizon ($horizon_time) is
                                shorter than interval ($interval) for $problem_name"))
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
    problems = get_problems(sim)
    # JDNOTE: this is limiting since it only allows updating from one problem
    for (key, chron) in get_sequence(sim).feedforward_chronologies
        destination_problem = problems[key.second]
        destination_problem_interval_ = get_interval(sequence, key.second)
        destination_problem_interval =
            IS.time_period_conversion(destination_problem_interval_)
        source_problem = problems[key.first]
        source_problem_number = get_simulation_number(source_problem)
        sim_info = get_simulation_info(destination_problem)
        sim_info.chronolgy_dict[source_problem_number] = chron
        source_problem_resolution_ = PSY.get_time_series_resolution(source_problem.sys)
        source_problem_resolution = IS.time_period_conversion(source_problem_resolution_)
        execution_wait_count = Int(source_problem_resolution / destination_problem_interval)
        set_execution_wait_count!(get_trigger(chron), execution_wait_count)
        initialize_trigger_count!(get_trigger(chron))
    end
    return
end

function _get_simulation_initial_times!(sim::Simulation)
    problem_initial_times = Dict{Int, Vector{Dates.DateTime}}()
    sim_ini_time = get_initial_time(sim)
    for (problem_number, (problem_name, problem)) in enumerate(get_problems(sim))
        problem_system = get_system(problem)
        system_interval = PSY.get_forecast_interval(problem_system)
        problem_interval = get_interval(get_sequence(sim), problem_name)
        if system_interval != problem_interval
            throw(
                IS.ConflictingInputsError(
                    "Simulation interval ($problem_interval) and forecast interval ($system_interval) definitions are not compatible",
                ),
            )
        end
        problem_horizon = get_horizon(problem)
        system_horizon = PSY.get_forecast_horizon(problem_system)
        if problem_horizon > system_horizon
            throw(
                IS.ConflictingInputsError(
                    "Simulation horizon ($problem_horizon) and forecast horizon ($system_horizon) definitions are not compatible",
                ),
            )
        end
        problem_initial_times[problem_number] =
            PSY.get_forecast_initial_times(problem_system)
        for (ix, element) in enumerate(problem_initial_times[problem_number][1:(end - 1)])
            if !(element + system_interval == problem_initial_times[problem_number][ix + 1])
                throw(IS.ConflictingInputsError("The sequence of forecasts is invalid"))
            end
        end
        if !(sim_ini_time === nothing) &&
           !mapreduce(x -> x == sim_ini_time, |, problem_initial_times[problem_number])
            throw(
                IS.ConflictingInputsError(
                    "The specified simulation initial_time $sim_ini_time isn't contained in problem $problem_number.
Manually provided initial times have to be compatible with the specified interval and horizon in the problems.",
                ),
            )
        end
    end
    if get_initial_time(sim) === nothing
        sim.initial_time = problem_initial_times[1][1]
        @debug("Initial Simulation Time will be infered from the data.
               Initial Simulation Time set to $(sim.initial_time)")
    end

    sim.internal.current_time = sim.initial_time
    return problem_initial_times
end

function _attach_feedforward!(sim::Simulation, problem_name::Symbol)
    problem = get_problems(sim)[problem_name]
    # JDNOTES: making a conversion here isn't great. Needs refactor
    feedforward =
        filter(p -> (Symbol(p.first[1]) == problem_name), get_sequence(sim).feedforward)
    for (key, ff) in feedforward
        # Note: key[1] = problem name, key[2] = template field name, key[3] = device model key
        field_dict = getfield(problem.template, key[2])
        device_model = get(field_dict, key[3], nothing)
        device_model === nothing && throw(
            IS.ConflictingInputsError(
                "Device model $(key[3]) not found in problem $(problem_name)",
            ),
        )
        attach_feedforward(device_model, ff)
    end
    return
end

function _check_steps(
    sim::Simulation,
    problem_initial_times::Dict{Int, Vector{Dates.DateTime}},
)
    sequence = get_sequence(sim)
    execution_order = get_execution_order(sequence)
    for (problem_number, (problem_name, problem)) in enumerate(get_problems(sim))
        execution_counts = get_executions(problem)
        # Checks the consistency between two methods of calculating the number of executions
        total_problem_executions =
            length(findall(x -> x == problem_number, execution_order))
        @assert_op total_problem_executions == execution_counts

        forecast_count = length(problem_initial_times[problem_number])
        if get_steps(sim) * execution_counts > forecast_count
            throw(
                IS.ConflictingInputsError(
                    "The number of available time series ($(forecast_count)) is not enough to perform the
desired amount of simulation steps ($(sim.steps*get_execution_count(problem))).",
                ),
            )
        end
    end
    return
end

function _check_required_ini_cond_caches(sim::Simulation)
    for (ix, (problem_name, problem)) in enumerate(get_problems(sim))
        optimization_container = get_optimization_container(problem)
        for (k, v) in iterate_initial_conditions(optimization_container)
            # No cache needed for the initial condition -> continue
            v[1].cache_type === nothing && continue
            c = get_cache(sim, v[1].cache_type, k.device_type)
            if c === nothing
                throw(
                    ArgumentError(
                        "Cache $(v[1].cache_type) not defined for initial condition $(k) in problem $problem_name",
                    ),
                )
            end
            @debug "found cache $(v[1].cache_type) for initial condition $(k) in problem $(problem_name)"
        end
    end
    return
end

function _populate_caches!(sim::Simulation, problem_name::Symbol)
    caches = get_problem_cache_definition(sim, problem_name)
    problem = get_problems(sim)[problem_name]
    # JDNOTES: Why passing here the internal and not the simulation cache ?
    _add_initial_condition_caches(sim.internal, problem, caches)
    _set_internal_caches(sim.internal, problem, caches)
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
    for (problem_number, (problem_name, problem)) in enumerate(get_problems(sim))
        @info("Building problem $(problem_number)-$(problem_name)")
        problem_chronology =
            get_problem_interval_chronology(get_sequence(sim), problem_name)
        initial_time = get_initial_time(sim)
        set_initial_time!(problem, initial_time)
        output_dir = joinpath(get_problems_dir(sim))
        set_output_dir!(problem, output_dir)
        initialize_simulation_info!(problem, problem_chronology)
        problem_build_status = _build!(problem, serialize)
        if problem_build_status != BuildStatus.BUILT
            error("Problem $(problem_name) failed to build succesfully")
        end
        _populate_caches!(sim, problem_name)
        sim.internal.date_ref[problem_number] = initial_time
    end
    _check_required_ini_cond_caches(sim)
    return
end

function _build!(sim::Simulation, serialize::Bool)
    set_simulation_build_status!(sim, BuildStatus.IN_PROGRESS)
    problem_initial_times = _get_simulation_initial_times!(sim)
    sequence = get_sequence(sim)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Assign FeedForward" begin
        for (ix, (problem_name, problem)) in enumerate(get_problems(sim))
            problem_interval = get_interval(sequence, problem_name)
            # Note to devs: Here we are setting the number of operations problem executions we
            # will see for every step of the simulation
            if ix == 1
                set_executions!(problem, 1)
            else
                step_resolution = get_step_resolution(sequence)
                set_executions!(problem, Int(step_resolution / problem_interval))
            end
            _attach_feedforward!(sim, problem_name)
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

Throws an exception if label is passed and the directory already exists.
"""
function build!(
    sim::Simulation;
    output_dir = nothing,
    recorders = [],
    console_level = Logging.Error,
    file_level = Logging.Info,
    serialize = true,
)
    TimerOutputs.reset_timer!(BUILD_PROBLEMS_TIMER)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build Simulation" begin
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Initialize Simulation" begin
            _check_forecasts_sequence(sim)
            _check_feedforward_chronologies(sim)
            _check_folder(sim)
            sim.internal = SimulationInternal(
                sim.steps,
                length(get_problems(sim)),
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
    @info "\n$(BUILD_PROBLEMS_TIMER)\n"
    return get_simulation_build_status(sim)
end

# Defined here because it requires problem and Simulation to defined

############################# Interfacing Functions ##########################################
# These are the functions that the user will have to implement to update a custom IC Chron #
# or custom InitialConditionType #

get_subcomponent_type(::ICKey{DevicePower, PSY.HybridSystem}) = PSY.ThermalGen
get_subcomponent_type(::ICKey{InitialTimeDurationOn, PSY.HybridSystem}) = PSY.ThermalGen
get_subcomponent_type(::ICKey{InitialTimeDurationOff, PSY.HybridSystem}) = PSY.ThermalGen
get_subcomponent_type(::ICKey{InitialEnergyLevel, PSY.HybridSystem}) = PSY.Storage

get_subcomponent_type(::ICKey) = nothing

""" Updates the initial conditions of the problem"""
function initial_condition_update!(
    problem::OperationsProblem,
    ini_cond_key::ICKey,
    initial_conditions::Vector{InitialCondition},
    ::IntraProblemChronology,
    sim::Simulation,
)
    # TODO: Replace this convoluted way to get information with access to data store
    simulation_cache = sim.internal.simulation_cache
    for ic in initial_conditions
        name = get_device_name(ic)
        interval_chronology =
            get_problem_interval_chronology(sim.sequence, get_name(problem))
        var_value = get_problem_variable(
            interval_chronology,
            (problem => problem),
            name,
            ic.update_ref;
            sub_component = get_subcomponent_type(ini_cond_key),
        )
        # We pass the simulation cache instead of the whole simulation to avoid definition dependencies.
        # All the inputs to calculate_ic_quantity are defined before the simulation object
        quantity = calculate_ic_quantity(
            ini_cond_key,
            ic,
            var_value,
            simulation_cache,
            get_resolution(problem),
        )
        previous_value = get_condition(ic)
        PJ.set_value(ic.value, quantity)
        IS.@record :simulation InitialConditionUpdateEvent(
            get_current_time(sim),
            ini_cond_key,
            ic,
            quantity,
            previous_value,
            get_simulation_number(problem),
        )
    end
end

""" Updates the initial conditions of the problem"""
function initial_condition_update!(
    problem::OperationsProblem,
    ini_cond_key::ICKey,
    initial_conditions::Vector{InitialCondition},
    ::InterProblemChronology,
    sim::Simulation,
)
    # TODO: Replace this convoluted way to get information with access to data store
    simulation_cache = sim.internal.simulation_cache
    execution_index = get_execution_order(sim)
    execution_count = get_execution_count(problem)
    problem_name = get_name(problem)
    sequence = get_sequence(sim)
    interval = get_interval(sequence, problem_name)
    for ic in initial_conditions
        name = get_device_name(ic)
        current_ix = get_current_execution_index(sim)
        source_problem_ix = current_ix == 1 ? last(execution_index) : current_ix - 1
        source_problem = get_problem(sim, execution_index[source_problem_ix])
        source_problem_name = get_name(source_problem)

        # If the problem that ran before is lower in the order of execution the chronology needs to grab the first result as the initial condition
        if get_simulation_number(source_problem) >= get_simulation_number(problem)
            interval_chronology =
                get_problem_interval_chronology(sequence, source_problem_name)
        elseif get_simulation_number(source_problem) < get_simulation_number(problem)
            interval_chronology = RecedingHorizon()
        end
        var_value = get_problem_variable(
            interval_chronology,
            (source_problem => problem),
            name,
            ic.update_ref;
            sub_component = get_subcomponent_type(ini_cond_key),
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
            get_simulation_number(problem),
        )
    end
    return
end

function _update_caches!(sim::Simulation, problem::OperationsProblem)
    for cache in get_caches(problem)
        update_cache!(sim, cache, problem)
    end
    return
end

################################ Cache Update ################################################
# TODO: Need to be careful here if 2 problems modify the same cache. This function might need
# dispatch on the Statge{OpModel} to assign different actions. e.g. HAUC and DAUC
function update_cache!(
    sim::Simulation,
    ::CacheKey{TimeStatusChange, D},
    problem::OperationsProblem,
) where {D <: PSY.Device}
    # TODO: Remove debug statements and use recorder here
    c = get_cache(sim, TimeStatusChange, D)
    increment = get_increment(sim, problem, c)
    variable = get_variable(problem.internal.optimization_container, c.ref)
    t_range = 1:get_end_of_interval_step(problem)
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

function get_increment(sim::Simulation, problem::OperationsProblem, cache::TimeStatusChange)
    units = cache.units
    problem_name = get_name(problem)
    sequence = get_sequence(sim)
    problem_interval = get_interval(sequence, problem_name)
    problem_resolution = problem_interval / units
    return problem_resolution
end

function update_cache!(
    sim::Simulation,
    ::CacheKey{StoredEnergy, D},
    problem::OperationsProblem,
) where {D <: PSY.Device}
    c = get_cache(sim, StoredEnergy, D)
    variable = get_variable(problem.internal.optimization_container, c.ref)
    t = get_end_of_interval_step(problem)
    for name in variable.axes[1]
        device_energy = JuMP.value(variable[name, t])
        @debug name, device_energy
        c.value[name] = device_energy
        @debug("Cache value StoredEnergy for device $name set to $(c.value[name])")
    end

    return
end

function update_cache!(
    sim::Simulation,
    ::CacheKey{StoredEnergy, D},
    problem::OperationsProblem,
) where {D <: PSY.HybridSystem}
    c = get_cache(sim, StoredEnergy, D)
    variable = get_variable(problem.internal.optimization_container, c.ref)
    t = get_end_of_interval_step(problem)
    for name in c.value.axes[1]
        device_energy = JuMP.value(variable[name, PSY.Storage, t])
        @debug name, device_energy
        c.value[name] = device_energy
        @debug("Cache value StoredEnergy for device $name set to $(c.value[name])")
    end

    return
end

######################### TimeSeries Data Updating###########################################
function update_parameter!(
    param_reference::UpdateRef{T},
    container::ParameterContainer,
    problem::OperationsProblem,
    sim::Simulation,
) where {T <: PSY.Component}
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "ts_update_parameter!" begin
        components = get_available_components(T, problem.sys)
        initial_forecast_time = get_simulation_time(sim, get_simulation_number(problem))
        horizon = length(model_time_steps(problem.internal.optimization_container))
        for d in components
            ts_vector = get_time_series_values!(
                PSY.Deterministic,
                problem,
                d,
                get_data_label(param_reference),
                initial_forecast_time,
                horizon,
                ignore_scaling_factors = true,
            )
            component_name = PSY.get_name(d)
            for (ix, val) in enumerate(get_parameter_array(container)[component_name, :])
                value = ts_vector[ix]
                JuMP.set_value(val, value)
            end
        end
    end

    return
end

function update_parameter!(
    param_reference::UpdateRef{T},
    container::ParameterContainer,
    problem::OperationsProblem,
    sim::Simulation,
) where {T <: PSY.Service}
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "ts_update_parameter!" begin
        components = get_available_components(T, problem.sys)
        initial_forecast_time = get_simulation_time(sim, get_simulation_number(problem))
        horizon = length(model_time_steps(problem.internal.optimization_container))
        param_array = get_parameter_array(container)
        for ix in axes(param_array)[1]
            service = PSY.get_component(T, problem.sys, ix)
            ts_vector = get_time_series_values!(
                PSY.Deterministic,
                problem,
                service,
                get_data_label(param_reference),
                initial_forecast_time,
                horizon,
                ignore_scaling_factors = true,
            )
            for (jx, value) in enumerate(ts_vector)
                JuMP.set_value(get_parameter_array(container)[ix, jx], value)
            end
        end
    end

    return
end

"""Updates the forecast parameter value"""
function update_parameter!(
    param_reference::UpdateRef{JuMP.VariableRef},
    container::ParameterContainer,
    problem::OperationsProblem,
    sim::Simulation,
)
    param_array = get_parameter_array(container)
    simulation_info = get_simulation_info(problem)
    for (k, chronology) in simulation_info.chronolgy_dict
        source_problem = get_problem(sim, k)
        feedforward_update!(
            problem,
            source_problem,
            chronology,
            param_reference,
            param_array,
            get_current_time(sim),
        )
    end

    return
end

function _update_initial_conditions!(problem::OperationsProblem, sim::Simulation)
    ini_cond_chronology = get_sequence(sim).ini_cond_chronology
    optimization_containter = get_optimization_container(problem)
    for (k, v) in iterate_initial_conditions(optimization_containter)
        initial_condition_update!(problem, k, v, ini_cond_chronology, sim)
    end
    return
end

function _update_parameters(problem::OperationsProblem, sim::Simulation)
    optimization_container = get_optimization_container(problem)
    for container in iterate_parameter_containers(optimization_container)
        update_parameter!(container.update_ref, container, problem, sim)
    end
    return
end

function _apply_warm_start!(problem::OperationsProblem)
    optimization_container = get_optimization_container(problem)
    jump_model = get_jump_model(optimization_container)
    all_vars = JuMP.all_variables(jump_model)
    JuMP.set_start_value.(all_vars, JuMP.value.(all_vars))
    return
end

""" Required update problem function call"""
function _update_problem!(problem::OperationsProblem, sim::Simulation)
    _update_parameters(problem, sim)
    _update_initial_conditions!(problem, sim)
    return
end

############################# Interfacing Functions##########################################
## These are the functions that the user will have to implement to update a custom problem ###
""" Generic problem update function for most problems with no customization"""
function update_problem!(
    problem::OperationsProblem{M},
    sim::Simulation,
) where {M <: PowerSimulationsOperationsProblem}
    _update_problem!(problem, sim)
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
    problems = get_problems(sim)

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
            for (ix, problem_number) in enumerate(execution_order)
                IS.@record :simulation_status ProblemExecutionEvent(
                    get_current_time(sim),
                    step,
                    problem_number,
                    "start",
                )
                problem_name = get_problem_names(problems)[problem_number]
                TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execute $(problem_name)" begin
                    problem = problems[problem_name]
                    if !is_built(problem)
                        error("$(problem_name) status is not BuildStatus.BUILT")
                    end
                    problem_interval = get_interval(sequence, problem_name)
                    set_current_time!(sim, sim.internal.date_ref[problem_number])
                    sequence.current_execution_index = ix
                    # Is first run of first problem? Yes -> don't update problem
                    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Update $(problem_name)" begin
                        !(step == 1 && ix == 1) && update_problem!(problem, sim)
                    end
                    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Run $(problem_name)" begin
                        settings = get_settings(problem)
                        status = solve!(
                            step,
                            problem,
                            get_current_time(sim),
                            store;
                            exports = exports,
                        )
                        global_problem_execution_count =
                            (step - 1) * length(execution_order) + ix
                        sim.internal.run_count[step][problem_number] += 1
                        sim.internal.date_ref[problem_number] += problem_interval
                        if get_allow_fails(settings) && (status != RunStatus.SUCCESSFUL)
                            continue
                        elseif !get_allow_fails(settings) &&
                               (status != RunStatus.SUCCESSFUL)
                            throw(
                                ErrorException(
                                    "Simulation Failed in problem $(problem_name). Returned $(status)",
                                ),
                            )
                        else
                            @assert status == RunStatus.SUCCESSFUL
                        end
                    end # Run problem Timer
                    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Update Cache $(problem_number)" begin
                        _update_caches!(sim, problem)
                    end
                    if warm_start_enabled(problem)
                        _apply_warm_start!(problem)
                    end
                    IS.@record :simulation_status ProblemExecutionEvent(
                        get_current_time(sim),
                        step,
                        problem_number,
                        "done",
                    )
                    ProgressMeter.update!(
                        prog_bar,
                        global_problem_execution_count;
                        showvalues = [
                            (:Step, step),
                            (:problem, problem_name),
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

    problems = OrderedDict{Symbol, SimulationStoreProblemParams}()
    problem_reqs = Dict{Symbol, SimulationStoreProblemRequirements}()
    num_param_containers = 0
    rules = CacheFlushRules(
        max_size = cache_size_mib * MiB,
        min_flush_size = min_cache_flush_size_mib,
    )
    for (problem_name, problem) in get_problems(sim)
        num_executions = executions_by_problem[problem_name]
        horizon = get_horizon(problem)
        optimization_container = get_optimization_container(problem)
        duals = get_constraint_duals(get_settings(optimization_container))
        parameters = get_parameters(optimization_container)
        variables = get_variables(optimization_container)
        aux_variables = get_aux_variables(optimization_container)
        num_rows = num_executions * get_steps(sim)

        interval = intervals[problem_name][1]
        resolution = get_resolution(problem)
        end_of_interval_step = get_end_of_interval_step(problem)
        system = get_system(problem)
        base_power = PSY.get_base_power(system)
        sys_uuid = IS.get_uuid(system)
        problem_params = SimulationStoreProblemParams(
            num_executions,
            horizon,
            interval,
            resolution,
            end_of_interval_step,
            base_power,
            sys_uuid,
        )
        reqs = SimulationStoreProblemRequirements()

        # TODO: configuration of keep_in_cache and priority are not correct
        problem_sym = Symbol(problem_name)
        for name in duals
            array = get_constraint(optimization_container, name)
            reqs.duals[Symbol(name)] = _calc_dimensions(array, name, num_rows, horizon)
            add_rule!(
                rules,
                problem_sym,
                STORE_CONTAINER_DUALS,
                name,
                false,
                CachePriority.LOW,
            )
        end

        if parameters !== nothing
            for (name, param_container) in parameters
                # TODO JD: this needs improvement
                !isa(param_container.update_ref, UpdateRef{<:PSY.Component}) && continue
                array = get_parameter_array(param_container)
                reqs.parameters[Symbol(name)] =
                    _calc_dimensions(array, name, num_rows, horizon)
                add_rule!(
                    rules,
                    problem_sym,
                    STORE_CONTAINER_PARAMETERS,
                    name,
                    false,
                    CachePriority.LOW,
                )
            end
        end

        for (name, array) in variables
            reqs.variables[Symbol(name)] = _calc_dimensions(array, name, num_rows, horizon)
            add_rule!(
                rules,
                problem_sym,
                STORE_CONTAINER_VARIABLES,
                name,
                false,
                CachePriority.HIGH,
            )
        end

        for (key, array) in aux_variables
            name = encode_key(key)
            reqs.variables[Symbol(name)] = _calc_dimensions(array, name, num_rows, horizon)
            add_rule!(
                rules,
                problem_sym,
                STORE_CONTAINER_VARIABLES,
                name,
                false,
                CachePriority.HIGH,
            )
        end

        problems[problem_sym] = problem_params
        problem_reqs[problem_sym] = reqs

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
    columns = unique([(k[1], k[2]) for k in keys(array.data)])
    final_column_names = Vector{Symbol}()
    for (ix, col) in enumerate(columns)
        res = values(filter(v -> (first(v)[[1, 2]] == col) && (last(v) != 0), array.data))
        if !isempty(res)
            push!(final_column_names, Symbol(col...))
        end
    end
    dims = (horizon, length(final_column_names), num_rows)
    return Dict("columns" => final_column_names, "dims" => dims)
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
    problems = get_problems(sim)
    for problem_name in get_problem_names(problems)
        problem = problems[problem_name]
        empty_time_series_cache!(problem)
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
    problems = get_problem_names(get_problems(sim))

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

        problems = Dict{Symbol, OperationsProblem{<:AbstractOperationsProblem}}()
        for name in obj.problems
            problem =
                deserialize_problem(OperationsProblem, joinpath("problems", "$(name).bin"))
            if !haskey(problem_info[key], "optimizer")
                throw(ArgumentError("problem_info must define 'optimizer'"))
            end
            problems[key] = wrapper.problem_type(
                wrapper.template,
                sys,
                restore_from_copy(
                    wrapper.settings;
                    optimizer = problem_info[key]["optimizer"],
                ),
                get(problem_info[key], "jump_model", nothing),
            )
        end

        sim = Simulation(;
            name = obj.name,
            steps = obj.steps,
            problems = SimulationProblems(problems...),
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
