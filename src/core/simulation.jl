
const SIMULATION_SERIALIZATION_FILENAME = "simulation.bin"
const SIMULATION_LOG_FILENAME = "simulation.log"
const REQUIRED_RECORDERS = [:simulation_status, :simulation]

mutable struct SimulationInternal
    sim_files_dir::String
    store_dir::String
    logs_dir::String
    models_dir::String
    recorder_dir::String
    results_dir::String
    stages_count::Int
    run_count::Dict{Int, Dict{Int, Int}}
    date_ref::Dict{Int, Dates.DateTime}
    time_step_ref::Dict{Int, Int}
    #Inital Time of the first forecast and Inital Time of the last forecast
    date_range::NTuple{2, Dates.DateTime}
    current_time::Dates.DateTime
    time_step::Int
    status::RUN_STATUS
    build_status::BUILD_STATUS
    simulation_cache::Dict{<:CacheKey, AbstractCache}
    recorders::Vector{Symbol}
    console_level::Base.CoreLogging.LogLevel
    file_level::Base.CoreLogging.LogLevel
end

function SimulationInternal(
    steps::Int,
    stages_keys::Base.KeySet,
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
        for st in stages_keys
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
    models_dir = joinpath(simulation_dir, "models_json")
    recorder_dir = joinpath(simulation_dir, "recorder")
    results_dir = joinpath(simulation_dir, "results")

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
    time_step = 1
    return SimulationInternal(
        sim_files_dir,
        store_dir,
        logs_dir,
        models_dir,
        recorder_dir,
        results_dir,
        length(stages_keys),
        count_dict,
        Dict{Int, Dates.DateTime}(),
        Dict{Int, Int}(),
        (init_time, init_time),
        init_time,
        time_step,
        NOT_RUNNING,
        EMPTY,
        Dict{CacheKey, AbstractCache}(),
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
    stage::Stage,
    caches::Union{Nothing, Vector{<:AbstractCache}},
)
    initial_conditions = stage.internal.psi_container.initial_conditions
    for (ic_key, init_conds) in initial_conditions.data
        _create_cache(ic_key, caches)
    end
    return
end

function _create_cache(ic_key::ICKey, caches::Union{Nothing, Vector{<:AbstractCache}})
    return
end

function _create_cache(
    ic_key::ICKey{TimeDurationON, T},
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
    ic_key::ICKey{TimeDurationOFF, T},
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
    ic_key::ICKey{EnergyLevel, T},
    caches::Vector{<:AbstractCache},
) where {T <: PSY.Device}
    cache_keys = CacheKey.(caches)
    if isempty(cache_keys) || !in(CacheKey(StoredEnergy, T), cache_keys)
        cache = StoredEnergy(T, ENERGY)
        push!(caches, cache)
    end
    return
end

function _set_internal_caches(
    internal::SimulationInternal,
    stage::Stage,
    caches::Vector{<:AbstractCache},
)
    for c in caches
        cache_key = CacheKey(c)
        push!(stage.internal.caches, cache_key)
        if !haskey(internal.simulation_cache, cache_key)
            @debug "Cache $(cache_key) added to the simulation"
            internal.simulation_cache[cache_key] = c
        end
        internal.simulation_cache[cache_key].value = get_initial_cache(c, stage)
    end
    return
end

function _get_output_dir_name(path, output_dir)
    if !isnothing(output_dir)
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
                stages::Dict{String, Stage{<:AbstractOperationsProblem}}
                sequence::Union{Nothing, SimulationSequence}
                simulation_folder::String
                name::String
                internal::Union{Nothing, SimulationInternal}
                )

"""
mutable struct Simulation
    steps::Int
    stages::Dict{String, Stage{<:AbstractOperationsProblem}}
    initial_time::Union{Nothing, Dates.DateTime}
    sequence::SimulationSequence
    simulation_folder::String
    name::String
    internal::Union{Nothing, SimulationInternal}

    function Simulation(;
        stages_sequence::SimulationSequence,
        name::String,
        steps::Int,
        stages = Dict{String, Stage{AbstractOperationsProblem}}(),
        simulation_folder::String,
        initial_time = nothing,
    )
        new(steps, stages, initial_time, stages_sequence, simulation_folder, name, nothing)
    end
end

"""
    Simulation(directory::AbstractString)

Constructs Simulation from a serialized directory. Callers should pass any kwargs here that
they passed to the original Simulation.

# Arguments
- `directory::AbstractString`: the directory returned from the call to serialize
- `stage_info::Dict`: Two-level dictionary containing stage parameters that cannot be
  serialized. The outer dict should be keyed by the stage name. The inner dict must contain
  'optimizer' and may contain 'jump_model'. These should be the same values used for the
  original simulation.
"""
function Simulation(directory::AbstractString, stage_info::Dict)
    obj = deserialize(Simulation, directory, stage_info)
end

################# accessor functions ####################
get_initial_time(sim::Simulation) = sim.initial_time
get_sequence(sim::Simulation) = sim.sequence
get_steps(sim::Simulation) = sim.steps
get_date_range(sim::Simulation) = sim.internal.date_range
get_current_time(sim::Simulation) = sim.internal.current_time
get_stages(sim::Simulation) = sim.stages
get_simulation_dir(sim::Simulation) = dirname(sim.internal.logs_dir)
get_simulation_files_dir(sim::Simulation) = sim.internal.sim_files_dir
get_store_dir(sim::Simulation) = sim.internal.store_dir
get_simulation_status(sim::Simulation) = sim.internal.status
get_simulation_build_status(sim::Simulation) = sim.internal.build_status

function get_base_powers(sim::Simulation)
    base_powers = Dict()
    for (name, stage) in get_stages(sim)
        base_powers[name] = PSY.get_base_power(get_system(stage))
    end
    return base_powers
end

function get_stage(sim::Simulation, name::String)
    stage = get(get_stages(sim), name, nothing)
    isnothing(stage) && throw(ArgumentError("Stage $(name) not present in the simulation"))
    return stage
end

get_stage_interval(sim::Simulation, name::String) = get_stage_interval(sim.sequence, name)

function get_stage(sim::Simulation, number::Int)
    name = get(get_sequence(sim).order, number, nothing)
    isnothing(name) && throw(ArgumentError("Stage with $(number) not defined"))
    return get_stage(sim, name)
end

get_stages_quantity(sim::Simulation) = sim.internal.stages_count

function get_simulation_time(sim::Simulation, stage_number::Int)
    return sim.internal.date_ref[stage_number]
end

function get_simulation_time_step(sim::Simulation, stage_number::Int)
    return sim.internal.time_step_ref[stage_number]
end

get_ini_cond_chronology(sim::Simulation) = get_sequence(sim).ini_cond_chronology
get_stage_name(sim::Simulation, stage::Stage) = get_stage_name(sim.sequence, stage)
IS.get_name(sim::Simulation) = sim.name
get_simulation_folder(sim::Simulation) = sim.simulation_folder
get_execution_order(sim::Simulation) = get_sequence(sim).execution_order
get_current_execution_index(sim::Simulation) = get_sequence(sim).current_execution_index
get_logs_folder(sim::Simulation) = sim.internal.logs_dir
get_recorder_folder(sim::Simulation) = sim.internal.recorder_dir

function get_stage_cache_definition(sim::Simulation, stage::String)
    caches = get_sequence(sim).cache
    cache_ref = Array{AbstractCache, 1}()
    for stage_names in keys(caches)
        if stage in stage_names
            push!(cache_ref, caches[stage_names])
        end
    end
    return cache_ref
end

function get_cache(simulation_cache::Dict{<:CacheKey, AbstractCache}, key::CacheKey)
    c = get(simulation_cache, key, nothing)
    isnothing(c) && @debug("Cache with key $(key) not present in the simulation")
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
    for (stage_number, stage_name) in get_sequence(sim).order
        stage = get_stage(sim, stage_name)
        resolution = get_resolution(stage)
        horizon = get_stage_horizon(get_sequence(sim), stage_name)
        interval = get_stage_interval(get_sequence(sim), stage_name)
        horizon_time = resolution * horizon
        if horizon_time < interval
            throw(IS.ConflictingInputsError("horizon ($horizon_time) is
                                shorter than interval ($interval) for $stage_name"))
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
    for (key, chron) in get_sequence(sim).feedforward_chronologies
        destination_stage = get_stage(sim, key.second)
        destination_stage_interval =
            IS.time_period_conversion(get_stage_interval(sim, key.second))
        source_stage_number = find_key_with_value(get_sequence(sim).order, key.first)
        if isempty(source_stage_number)
            throw(ArgumentError("Stage $(key.first) not specified in the order dictionary"))
        end
        for stage_number in source_stage_number
            destination_stage.internal.chronolgy_dict[stage_number] = chron
            source_stage = get_stage(sim, stage_number)
            source_stage_resolution =
                IS.time_period_conversion(PSY.get_time_series_resolution(source_stage.sys))
            execution_wait_count = Int(source_stage_resolution / destination_stage_interval)
            set_execution_wait_count!(get_trigger(chron), execution_wait_count)
            initialize_trigger_count!(get_trigger(chron))
        end
    end
    return
end

function _get_simulation_initial_times!(sim::Simulation)
    k = keys(get_sequence(sim).order)
    k_size = length(k)
    @assert k_size == maximum(k)

    stage_initial_times = Dict{Int, Vector{Dates.DateTime}}()
    time_range = Vector{Dates.DateTime}(undef, 2)
    sim_ini_time = get_initial_time(sim)
    for (stage_number, stage_name) in get_sequence(sim).order
        stage_system = sim.stages[stage_name].sys
        system_interval = PSY.get_forecast_interval(stage_system)
        stage_interval = get_stage_interval(get_sequence(sim), stage_name)
        if system_interval != stage_interval
            throw(IS.ConflictingInputsError("Simulation interval ($stage_interval) and forecast interval ($system_interval) definitions are not compatible"))
        end
        stage_horizon = get_stage_horizon(get_sequence(sim), stage_name)
        system_horizon = PSY.get_forecast_horizon(stage_system)
        if stage_horizon > system_horizon
            throw(IS.ConflictingInputsError("Simulation horizon ($stage_horizon) and forecast horizon ($system_horizon) definitions are not compatible"))
        end
        stage_initial_times[stage_number] = PSY.get_forecast_initial_times(stage_system)
        for (ix, element) in enumerate(stage_initial_times[stage_number][1:(end - 1)])
            if !(element + system_interval == stage_initial_times[stage_number][ix + 1])
                throw(IS.ConflictingInputsError("The sequence of forecasts is invalid"))
            end
        end
        if !isnothing(sim_ini_time) &&
           !mapreduce(x -> x == sim_ini_time, |, stage_initial_times[stage_number])
            throw(IS.ConflictingInputsError("The specified simulation initial_time $sim_ini_time isn't contained in stage $stage_number.
            Manually provided initial times have to be compatible with the specified interval and horizon in the stages."))
        end
        stage_number == 1 && (time_range[1] = stage_initial_times[stage_number][1])
        (
            stage_number == k_size &&
            (time_range[end] = stage_initial_times[stage_number][end])
        )
    end
    sim.internal.date_range = Tuple(time_range)

    if isnothing(get_initial_time(sim))
        sim.initial_time = stage_initial_times[1][1]
        @debug("Initial Simulation Time will be infered from the data.
               Initial Simulation Time set to $(sim.initial_time)")
    end

    sim.internal.current_time = sim.initial_time
    return stage_initial_times
end

function _attach_feedforward!(sim::Simulation, stage_name::String)
    stage = get(sim.stages, stage_name, nothing)
    feedforward = filter(p -> (p.first[1] == stage_name), get_sequence(sim).feedforward)
    for (key, ff) in feedforward
        # Note: key[1] = Stage name, key[2] = template field name, key[3] = device model key
        field_dict = getfield(stage.template, key[2])
        device_model = get(field_dict, key[3], nothing)
        isnothing(device_model) &&
            throw(IS.ConflictingInputsError("Device model $(key[3]) not found in stage $(stage_name)"))
        device_model.feedforward = ff
    end
    return
end

function _check_steps(
    sim::Simulation,
    stage_initial_times::Dict{Int, Vector{Dates.DateTime}},
)
    for (stage_number, stage_name) in get_sequence(sim).order
        stage = sim.stages[stage_name]
        execution_counts = get_executions(stage)
        transitions = get_sequence(sim).execution_order[vcat(
            1,
            diff(get_sequence(sim).execution_order),
        ) .== 1]
        @assert length(findall(x -> x == stage_number, get_sequence(sim).execution_order)) /
                length(findall(x -> x == stage_number, transitions)) == execution_counts
        forecast_count = length(stage_initial_times[stage_number])
        if get_steps(sim) * execution_counts > forecast_count
            throw(IS.ConflictingInputsError("The number of available time series ($(forecast_count)) is not enough to perform the
            desired amount of simulation steps ($(sim.steps*get_execution_count(stage)))."))
        end
    end
    return
end

function _check_required_ini_cond_caches(sim::Simulation)
    for (stage_number, stage_name) in get_sequence(sim).order
        stage = get_stage(sim, stage_name)
        for (k, v) in iterate_initial_conditions(stage.internal.psi_container)
            # No cache needed for the initial condition -> continue
            isnothing(v[1].cache_type) && continue
            c = get_cache(sim, v[1].cache_type, k.device_type)
            if isnothing(c)
                throw(ArgumentError("Cache $(v[1].cache_type) not defined for initial condition $(k) in stage $stage_name"))
            end
            @debug "found cache $(v[1].cache_type) for initial condition $(k) in stage $(stage_name)"
        end
    end
    return
end

function _populate_caches!(sim::Simulation, stage_name::String)
    caches = get_stage_cache_definition(sim, stage_name)
    stage = get_stage(sim, stage_name)
    _add_initial_condition_caches(sim.internal, stage, caches)
    _set_internal_caches(sim.internal, stage, caches)
    return
end

function _build_stages!(sim::Simulation)
    for (stage_number, stage_name) in get_sequence(sim).order
        TimerOutputs.@timeit BUILD_SIMULATION_TIMER "Build Stage $(stage_name)" begin
            @info("Building Stage $(stage_number)-$(stage_name)")
            horizon = get_stage_horizon(get_sequence(sim), stage_name)
            stage = get_stage(sim, stage_name)
            stage_interval = get_stage_interval(get_sequence(sim), stage_name)
            initial_time = get_initial_time(sim)
            set_write_path!(stage, get_simulation_dir(sim))
            build!(stage, initial_time, horizon, stage_interval)
            _populate_caches!(sim, stage_name)
            sim.internal.date_ref[stage_number] = initial_time
            sim.internal.time_step_ref[stage_number] = 1
        end
    end
    _check_required_ini_cond_caches(sim)
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

"""
    build!(sim::Simulation)

Build the Simulation and all stages.

# Arguments
- `sim::Simulation`: simulation object
- `output_dir = nothing`: If nothing then generate a unique name.
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
    TimerOutputs.reset_timer!(BUILD_SIMULATION_TIMER)
    TimerOutputs.@timeit BUILD_SIMULATION_TIMER "Build Simulation" begin
        _check_forecasts_sequence(sim)
        _check_feedforward_chronologies(sim)
        _check_folder(sim)
        sim.internal = SimulationInternal(
            sim.steps,
            keys(get_sequence(sim).order),
            get_simulation_folder(sim),
            get_name(sim);
            output_dir = output_dir,
            recorders = recorders,
            console_level = console_level,
            file_level = file_level,
        )

        file_mode = "w"
        logger = configure_logging(sim.internal, file_mode)
        register_recorders!(sim.internal, file_mode)
        try
            Logging.with_logger(logger) do
                _build!(sim, serialize)
                sim.internal.build_status = BUILT
                @info "\n$(BUILD_SIMULATION_TIMER)\n"
            end
        finally
            unregister_recorders!(sim.internal)
            close(logger)
        end
    end
    return
end

function _build!(sim::Simulation, serialize::Bool)
    sim.internal.build_status = IN_PROGRESS
    stage_initial_times = _get_simulation_initial_times!(sim)
    sequence = get_sequence(sim)
    for (stage_number, stage_name) in get_order(sequence)
        stage = get_stage(sim, stage_name)
        if isnothing(stage)
            throw(IS.ConflictingInputsError("Stage $(stage_name) not found in the stages definitions"))
        end
        stage_interval = get_stage_interval(sim, stage_name)
        step_resolution =
            stage_number == 1 ? get_step_resolution(sim.sequence) :
            get_stage_interval(sequence, get_order(sequence)[stage_number - 1])
        stage.internal.executions = Int(step_resolution / stage_interval)
        stage.internal.number = stage_number
        stage.internal.name = stage_name
        _attach_feedforward!(sim, stage_name)
    end
    _assign_feedforward_chronologies(sim)
    _check_steps(sim, stage_initial_times)
    _build_stages!(sim)
    if serialize
        TimerOutputs.@timeit BUILD_SIMULATION_TIMER "Serializing Simulation Files" begin
            serialize_simulation(sim)
        end
    end
    return
end

#Defined here because it requires Stage and Simulation to defined

#############################Interfacing Functions##########################################
# These are the functions that the user will have to implement to update a custom IC Chron #
# or custom InitialConditionType #

""" Updates the initial conditions of the stage"""
function initial_condition_update!(
    stage::Stage,
    ini_cond_key::ICKey,
    initial_conditions::Vector{InitialCondition},
    ::IntraStageChronology,
    sim::Simulation,
)
    # TODO: Replace this convoluted way to get information with access to data store
    simulation_cache = sim.internal.simulation_cache
    for ic in initial_conditions
        name = device_name(ic)
        interval_chronology =
            get_stage_interval_chronology(sim.sequence, get_stage_name(sim, stage))
        var_value =
            get_stage_variable(interval_chronology, (stage => stage), name, ic.update_ref)
        # We pass the simulation cache instead of the whole simulation to avoid definition dependencies.
        # All the inputs to calculate_ic_quantity are defined before the simulation object
        quantity = calculate_ic_quantity(
            ini_cond_key,
            ic,
            var_value,
            simulation_cache,
            get_resolution(stage),
        )
        previous_value = get_condition(ic)
        PJ.fix(ic.value, quantity)
        IS.@record :simulation InitialConditionUpdateEvent(
            get_current_time(sim),
            sim.internal.time_step,
            ini_cond_key,
            ic,
            quantity,
            previous_value,
            get_number(stage),
        )
    end
end

""" Updates the initial conditions of the stage"""
function initial_condition_update!(
    stage::Stage,
    ini_cond_key::ICKey,
    initial_conditions::Vector{InitialCondition},
    ::InterStageChronology,
    sim::Simulation,
)
    # TODO: Replace this convoluted way to get information with access to data store
    simulation_cache = sim.internal.simulation_cache
    execution_index = get_execution_order(sim)
    execution_count = get_execution_count(stage)
    stage_name = get_stage_name(sim, stage)
    interval = get_stage_interval(sim, stage_name)
    for ic in initial_conditions
        name = device_name(ic)
        current_ix = get_current_execution_index(sim)
        source_stage_ix = current_ix == 1 ? last(execution_index) : current_ix - 1
        source_stage = get_stage(sim, execution_index[source_stage_ix])
        source_stage_name = get_stage_name(sim, source_stage)

        # If the stage that ran before is lower in the order of execution the chronology needs to grab the first result as the initial condition
        if get_number(source_stage) >= get_number(stage)
            interval_chronology =
                get_stage_interval_chronology(sim.sequence, source_stage_name)
        elseif get_number(source_stage) < get_number(stage)
            interval_chronology = RecedingHorizon()
        end

        var_value = get_stage_variable(
            interval_chronology,
            (source_stage => stage),
            name,
            ic.update_ref,
        )
        quantity =
            calculate_ic_quantity(ini_cond_key, ic, var_value, simulation_cache, interval)
        previous_value = get_condition(ic)
        PJ.fix(ic.value, quantity)
        IS.@record :simulation InitialConditionUpdateEvent(
            get_current_time(sim),
            sim.internal.time_step,
            ini_cond_key,
            ic,
            quantity,
            previous_value,
            get_number(stage),
        )
    end
    return
end

function _update_caches!(sim::Simulation, stage::Stage)
    for cache in stage.internal.caches
        update_cache!(sim, cache, stage)
    end
    return
end

################################Cache Update################################################
# TODO: Need to be careful here if 2 stages modify the same cache. This function might need
# dispatch on the Statge{OpModel} to assign different actions. e.g. HAUC and DAUC
function update_cache!(
    sim::Simulation,
    ::CacheKey{TimeStatusChange, D},
    stage::Stage,
) where {D <: PSY.Device}
    # TODO: Remove debug statements and use recorder here
    c = get_cache(sim, TimeStatusChange, D)
    increment = get_increment(sim, stage, c)
    variable = get_variable(stage.internal.psi_container, c.ref)
    t_range = 1:get_end_of_interval_step(stage)
    for name in variable.axes[1]
        #Store the initial condition
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
                @debug("Cache value TimeStatus for device $name set to $device_status and count to $(c.value[name][:count])")
            else
                c.value[name][:count] = increment
                c.value[name][:status] = device_status
                @debug("Cache value TimeStatus for device $name set to $device_status and count to 1.0")
            end
        end
    end

    return
end

function get_increment(sim::Simulation, stage::Stage, cache::TimeStatusChange)
    units = cache.units
    stage_name = get_stage_name(sim, stage)
    stage_interval = IS.time_period_conversion(get_stage_interval(sim, stage_name))
    horizon = get_stage_horizon(sim.sequence, stage_name)
    stage_resolution = stage_interval / horizon
    return float(stage_resolution / units)
end

function update_cache!(
    sim::Simulation,
    ::CacheKey{StoredEnergy, D},
    stage::Stage,
) where {D <: PSY.Device}
    c = get_cache(sim, StoredEnergy, D)
    variable = get_variable(stage.internal.psi_container, c.ref)
    t = get_end_of_interval_step(stage)
    for name in variable.axes[1]
        device_energy = JuMP.value(variable[name, t])
        @debug name, device_energy
        c.value[name] = device_energy
        @debug("Cache value StoredEnergy for device $name set to $(c.value[name])")
    end

    return
end

#########################TimeSeries Data Updating###########################################
function update_parameter!(
    param_reference::UpdateRef{T},
    container::ParameterContainer,
    stage::Stage,
    sim::Simulation,
) where {T <: PSY.Component}
    components = get_available_components(T, stage.sys)
    initial_forecast_time = get_simulation_time(sim, get_number(stage))
    horizon = length(model_time_steps(stage.internal.psi_container))
    for d in components
        # RECORDER TODO: Parameter Update from forecast
        # TODO: Improve file read performance
        forecast = PSY.get_time_series(
            PSY.Deterministic,
            d,
            get_data_label(param_reference);
            start_time = initial_forecast_time,
            count = 1,
        )
        ts_vector = IS.get_time_series_values(
            d,
            forecast,
            initial_forecast_time;
            len = horizon,
            ignore_scaling_factors = true,
        )
        component_name = PSY.get_name(d)
        for (ix, val) in enumerate(get_parameter_array(container)[component_name, :])
            value = ts_vector[ix]
            JuMP.fix(val, value)
        end
    end

    return
end

function update_parameter!(
    param_reference::UpdateRef{T},
    container::ParameterContainer,
    stage::Stage,
    sim::Simulation,
) where {T <: PSY.Service}
    # RECORDER TODO: Parameter Update from forecast
    components = get_available_components(T, stage.sys)
    initial_forecast_time = get_simulation_time(sim, get_number(stage))
    horizon = length(model_time_steps(stage.internal.psi_container))
    param_array = get_parameter_array(container)
    for ix in axes(param_array)[1]
        service = PSY.get_component(T, stage.sys, ix)
        forecast = PSY.get_time_series(
            PSY.Deterministic,
            service,
            get_data_label(param_reference);
            start_time = initial_forecast_time,
            count = 1,
        )
        ts_vector = IS.get_time_series_values(
            service,
            forecast,
            initial_forecast_time;
            len = horizon,
            ignore_scaling_factors = true,
        )
        for (jx, value) in enumerate(ts_vector)
            JuMP.fix(get_parameter_array(container)[ix, jx], value)
        end
    end

    return
end

"""Updates the forecast parameter value"""
function update_parameter!(
    param_reference::UpdateRef{JuMP.VariableRef},
    container::ParameterContainer,
    stage::Stage,
    sim::Simulation,
)
    param_array = get_parameter_array(container)
    for (k, chronology) in stage.internal.chronolgy_dict
        source_stage = get_stage(sim, k)
        feedforward_update!(
            stage,
            source_stage,
            chronology,
            param_reference,
            param_array,
            get_current_time(sim),
        )
    end

    return
end

function _update_initial_conditions!(stage::Stage, sim::Simulation)
    ini_cond_chronology = get_sequence(sim).ini_cond_chronology
    for (k, v) in iterate_initial_conditions(stage.internal.psi_container)
        initial_condition_update!(stage, k, v, ini_cond_chronology, sim)
    end
    return
end

function _update_parameters(stage::Stage, sim::Simulation)
    for container in iterate_parameter_containers(stage.internal.psi_container)
        update_parameter!(container.update_ref, container, stage, sim)
    end
    return
end

function _apply_warm_start!(stage::Stage)
    for variable in values(stage.internal.psi_container.variables)
        for e in variable
            current_solution = JuMP.value(e)
            JuMP.set_start_value(e, current_solution)
        end
    end
    return
end

""" Required update stage function call"""
function _update_stage!(stage::Stage, sim::Simulation)
    _update_parameters(stage, sim)
    _update_initial_conditions!(stage, sim)
    return
end

#############################Interfacing Functions##########################################
## These are the functions that the user will have to implement to update a custom stage ###
""" Generic Stage update function for most problems with no customization"""
function update_stage!(
    stage::Stage{M},
    sim::Simulation,
) where {M <: PowerSimulationsOperationsProblem}
    _update_stage!(stage, sim)
    return
end

get_simulation_store_open_func(sim::Simulation) = h5_store_open

"""
    execute!(sim::Simulation; kwargs...)

Solves the simulation model for sequential Simulations
and populates a nested folder structure created in Simulation()
with a dated folder of featherfiles that contain the results for
each stage and step.

# Arguments
- `sim::Simulation=sim`: simulation object created by Simulation()

# Example
```julia
sim = Simulation("Test", 7, stages, "/Users/folder")
execute!(sim::Simulation; kwargs...)
```
"""

function execute!(sim::Simulation; kwargs...)
    file_mode = "a"
    logger = configure_logging(sim.internal, file_mode)
    register_recorders!(sim.internal, file_mode)
    open_func = get_simulation_store_open_func(sim)
    results = nothing
    # TODO: return file name for hash calculation instead of hard code
    try
        open_func(get_store_dir(sim), "w") do store
            Logging.with_logger(logger) do
                results = _execute!(sim, store; kwargs...)
                log_cache_hit_percentages(store)
            end
        end

    finally
        unregister_recorders!(sim.internal)
        close(logger)
    end
    compute_file_hash(get_store_dir(sim), HDF_FILENAME)
    return results
end

function _execute!(sim::Simulation, store; cache_size_mib = 1024, kwargs...)
    if get_simulation_build_status(sim) != BUILT
        error("Simulation status is $(get_simulation_status(sim)), try to rebuild the simulation")
    end
    @assert !isnothing(sim.internal)
    execution_order = get_execution_order(sim)
    steps = get_steps(sim)
    num_executions = steps * length(execution_order)
    _initialize_stage_storage!(sim, store, cache_size_mib)
    initialize_optimizer_stats_storage!(store, num_executions)
    TimerOutputs.reset_timer!(RUN_SIMULATION_TIMER)
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execute Simulation" begin
        for step in 1:steps
            TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execution Step $(step)" begin
                println("Executing Step $(step)")
                IS.@record :simulation_status SimulationStepEvent(
                    get_current_time(sim),
                    sim.internal.time_step,
                    step,
                    "start",
                )
                for (ix, stage_number) in enumerate(execution_order)
                    IS.@record :simulation_status SimulationStageEvent(
                        get_current_time(sim),
                        sim.internal.time_step,
                        step,
                        stage_number,
                        "start",
                    )
                    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execution Stage $(stage_number)" begin
                        # TODO: implement some efficient way of indexing with stage name.
                        stage = get_stage(sim, stage_number)
                        stage_name = get_stage_name(sim, stage)
                        if !is_stage_built(stage)
                            error("Stage $(stage_name) status is not BUILT")
                        end
                        stage_interval = get_stage_interval(sim, stage_name)
                        run_name = "step-$(step)-stage-$(stage_name)"
                        sim.internal.current_time = sim.internal.date_ref[stage_number]
                        sim.internal.time_step = sim.internal.time_step_ref[stage_number]
                        # TODO: Show progress meter here
                        get_sequence(sim).current_execution_index = ix
                        @info "Starting run $run_name $(get_current_time(sim))"
                        # Is first run of first stage? Yes -> don't update stage
                        TimerOutputs.@timeit RUN_SIMULATION_TIMER "Update Stage $(stage_number)" begin
                            !(step == 1 && ix == 1) && update_stage!(stage, sim)
                        end
                        TimerOutputs.@timeit RUN_SIMULATION_TIMER "Run Stage $(stage_number)" begin
                            stage_name = get_stage_name(sim, stage)
                            settings = get_settings(stage)
                            # TODO: Add Fallback when run_stage fails
                            status = run_stage!(step, stage, get_current_time(sim), store)
                            if status == SUCESSFUL_RUN
                                flush(store)
                            elseif !get_allow_fails(settings) && (status != SUCESSFUL_RUN)
                                break
                            elseif get_allow_fails(settings) && (status != SUCESSFUL_RUN)
                                continue
                            elseif status == RUNNING
                                error("Stage still in RUNNING status")
                            else
                                error("Invalid stage status")
                            end

                            sim.internal.run_count[step][stage_number] += 1
                        end
                        TimerOutputs.@timeit RUN_SIMULATION_TIMER "Update Cache $(stage_number)" begin
                            _update_caches!(sim, stage)
                        end
                        if warm_start_enabled(stage)
                            TimerOutputs.@timeit RUN_SIMULATION_TIMER "Warm Start $(stage_number)" begin
                                _apply_warm_start!(stage)
                            end
                        end
                    end
                    IS.@record :simulation_status SimulationStageEvent(
                        get_current_time(sim),
                        sim.internal.time_step,
                        step,
                        stage_number,
                        "done",
                    )
                    sim.internal.date_ref[stage_number] += stage_interval
                    sim.internal.time_step_ref[stage_number] += 1
                end
                IS.@record :simulation_status SimulationStepEvent(
                    get_current_time(sim),
                    sim.internal.time_step,
                    step,
                    "done",
                )
            end
        end
        flush(store)
    end
    @info ("\n$(RUN_SIMULATION_TIMER)\n")
    #serialize_sim_output(sim_results)
    return nothing #sim_results
end

function _initialize_stage_storage!(sim::Simulation, store, cache_size_mib)
    sequence = sim.sequence
    execution_order = sequence.execution_order
    executions_by_stage = sequence.executions_by_stage
    horizons = sequence.horizons
    intervals = sequence.intervals
    order = sequence.order

    stages = OrderedDict{Symbol, SimulationStoreStageParams}()
    stage_reqs = Dict{Symbol, SimulationStoreStageRequirements}()
    stage_order = [order[x] for x in sort!(collect(keys(order)))]
    num_param_containers = 0
    rules = CacheFlushRules(max_size = cache_size_mib * MiB)
    for stage_name in stage_order
        num_executions = executions_by_stage[stage_name]
        horizon = horizons[stage_name]
        stage = sim.stages[stage_name]
        psi_container = get_psi_container(stage)
        duals = get_constraint_duals(psi_container.settings)
        parameters = get_parameters(psi_container)
        variables = get_variables(psi_container)
        num_rows = num_executions * get_steps(sim)

        # TODO DT: not sure this is correct
        interval = intervals[stage_name][1]
        resolution = get_resolution(stage)
        system = get_system(stage)
        base_power = PSY.get_base_power(system)
        sys_uuid = IS.get_uuid(system)
        stage_params = SimulationStoreStageParams(num_executions, horizon, interval, resolution, base_power, sys_uuid)
        reqs = SimulationStoreStageRequirements()

        # TODO DT: configuration of keep_in_cache and priority are not correct
        stage_sym = Symbol(stage_name)
        for name in duals
            array = get_constraint(psi_container, name)
            reqs.duals[Symbol(name)] = _calc_dimensions(array, name, num_rows, horizon)
            add_rule!(
                rules,
                stage_sym,
                CONTAINER_TYPE_DUALS,
                name,
                false,
                CachePrioritys.LOW,
            )
        end

        for (name, param_container) in parameters
            # TODO JD: this needs improvement
            !isa(param_container.update_ref, UpdateRef{<:PSY.Component}) && continue
            array = get_parameter_array(param_container)
            reqs.parameters[Symbol(name)] = _calc_dimensions(array, name, num_rows, horizon)
            add_rule!(
                rules,
                stage_sym,
                CONTAINER_TYPE_PARAMETERS,
                name,
                false,
                CachePrioritys.LOW,
            )
        end

        for (name, array) in variables
            reqs.variables[Symbol(name)] = _calc_dimensions(array, name, num_rows, horizon)
            add_rule!(
                rules,
                stage_sym,
                CONTAINER_TYPE_VARIABLES,
                name,
                true,
                CachePrioritys.HIGH,
            )
        end

        stages[stage_sym] = stage_params
        stage_reqs[stage_sym] = reqs

        num_param_containers +=
            length(reqs.duals) + length(reqs.parameters) + length(reqs.variables)
    end

    store_params = SimulationStoreParams(
        get_initial_time(sim),
        sequence.step_resolution,
        get_steps(sim),
        stages,
    )
    @debug "initialized stage requirements" store_params
    initialize_stage_storage!(store, store_params, stage_reqs, rules)
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
    elseif length(ax) == 3
        # TODO DT: untested
        dims = (length(ax[2]), horizon, length(columns), num_rows)
    else
        error("unsupported data size $(length(ax))")
    end

    return Dict("columns" => columns, "dims" => dims)
end

function _calc_dimensions(array::JuMP.Containers.SparseAxisArray, name, num_rows, horizon)
    columns = unique([(k[1], k[3]) for k in keys(array.data)])
    dims = (horizon, length(columns), num_rows)  # TODO DT: what about 2-d arrays?
    @warn "SparseAxisArray dimensions may be incorrect" name dims
    return Dict("columns" => columns, "dims" => dims)
end

struct SimulationSerializationWrapper
    steps::Int
    stages::Dict{String, StageSerializationWrapper}
    initial_time::Union{Nothing, Dates.DateTime}
    sequence::Union{Nothing, SimulationSequence}
    simulation_folder::String
    name::String
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
function serialize_simulation(sim::Simulation; force = false)
    directory = get_simulation_files_dir(sim)
    stages = Dict{String, StageSerializationWrapper}()

    orig = pwd()
    if !isempty(readdir(directory)) && !force
        throw(ArgumentError("$directory has files already $(readdir(directory)). Please delete them or pass force = true."))
    end
    rm(directory, recursive = true, force = true)
    mkdir(directory)
    cd(directory)

    try
        for (key, stage) in get_stages(sim)
            if isnothing(stage.internal)
                throw(ArgumentError("stage $(stage.internal.number) has not been built"))
            end
            sys_filename = "system-$(IS.get_uuid(stage.sys)).json"
            # Skip serialization if multiple stages have the same system.
            if !ispath(sys_filename)
                PSY.to_json(stage.sys, sys_filename)
            end
            stages[key] = StageSerializationWrapper(
                stage.template,
                sys_filename,
                stage.internal.psi_container.settings_copy,
                typeof(stage),
            )
        end
    finally
        cd(orig)
    end

    filename = joinpath(directory, SIMULATION_SERIALIZATION_FILENAME)
    obj = SimulationSerializationWrapper(
        get_steps(sim),
        stages,
        get_initial_time(sim),
        get_sequence(sim),
        get_simulation_dir(sim),
        get_name(sim),
    )
    Serialization.serialize(filename, obj)
    @info "Serialized simulation" get_name(sim) directory
    return directory
end

function deserialize(::Type{Simulation}, directory::AbstractString, stage_info::Dict)
    orig = pwd()
    cd(directory)

    try
        filename = SIMULATION_SERIALIZATION_FILENAME
        if !ispath(filename)
            throw(ArgumentError("$filename does not exist"))
        end

        obj = Serialization.deserialize(filename)
        if !(obj isa SimulationSerializationWrapper)
            throw(IS.DataFormatError("deserialized object has incorrect type $(typeof(obj))"))
        end

        stages = Dict{String, Stage{<:AbstractOperationsProblem}}()
        for (key, wrapper) in obj.stages
            sys_filename = wrapper.sys
            if !ispath(sys_filename)
                throw(ArgumentError("stage PowerSystems serialized file $sys_filename does not exist"))
            end
            sys = PSY.System(sys_filename)
            if !haskey(stage_info[key], "optimizer")
                throw(ArgumentError("stage_info must define 'optimizer'"))
            end
            stages[key] = wrapper.stage_type(
                wrapper.template,
                sys,
                restore_from_copy(
                    wrapper.settings;
                    optimizer = stage_info[key]["optimizer"],
                ),
                get(stage_info[key], "jump_model", nothing),
            )
        end

        sim = Simulation(;
            name = obj.name,
            steps = obj.steps,
            stages = stages,
            stages_sequence = obj.sequence,
            simulation_folder = obj.simulation_folder,
        )
        return sim
    finally
        cd(orig)
    end
end
