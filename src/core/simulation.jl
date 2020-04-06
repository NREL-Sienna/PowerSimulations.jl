
const SIMULATION_SERIALIZATION_FILENAME = "simulation.bin"

mutable struct SimulationInternal
    raw_dir::Union{String, Nothing}
    models_dir::Union{String, Nothing}
    results_dir::Union{String, Nothing}
    stages_count::Int
    run_count::Dict{Int, Dict{Int, Int}}
    date_ref::Dict{Int, Dates.DateTime}
    date_range::NTuple{2, Dates.DateTime} #Inital Time of the first forecast and Inital Time of the last forecast
    current_time::Dates.DateTime
    reset::Bool
    compiled_status::Bool
    simulation_cache::Dict{<:CacheKey, AbstractCache}
end

function SimulationInternal(steps::Int, stages_keys::Base.KeySet)
    count_dict = Dict{Int, Dict{Int, Int}}()

    for s in 1:steps
        count_dict[s] = Dict{Int, Int}()
        for st in stages_keys
            count_dict[s][st] = 0
        end
    end

    return SimulationInternal(
        nothing,
        nothing,
        nothing,
        length(stages_keys),
        count_dict,
        Dict{Int, Dates.DateTime}(),
        (Dates.now(), Dates.now()),
        Dates.now(),
        true,
        false,
        Dict{CacheKey, AbstractCache}(),
    )
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

const DEFAULT_RECORDERS = [:simulation_states]

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
    recorders::Vector{Symbol}

    function Simulation(;
        stages_sequence::SimulationSequence,
        name::String,
        steps::Int,
        stages = Dict{String, Stage{AbstractOperationsProblem}}(),
        simulation_folder::String,
        initial_time = nothing,
        recorders = DEFAULT_RECORDERS,
    )
        new(
            steps,
            stages,
            initial_time,
            stages_sequence,
            simulation_folder,
            name,
            nothing,
            recorders,
        )
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
get_initial_time(s::Simulation) = s.initial_time
get_sequence(s::Simulation) = s.sequence
get_steps(s::Simulation) = s.steps
get_date_range(s::Simulation) = s.internal.date_range

function get_base_powers(s::Simulation)
    base_powers = Dict()
    for (k, v) in s.stages
        base_powers[k] = v.sys.base_powers
    end
    return base_powers
end

function get_stage(s::Simulation, name::String)
    stage = get(s.stages, name, nothing)
    isnothing(stage) && throw(ArgumentError("Stage $(name) not present in the simulation"))
    return stage
end

get_stage_interval(s::Simulation, name::String) = get_stage_interval(s.sequence, name)

function get_stage(s::Simulation, number::Int)
    name = get(s.sequence.order, number, nothing)
    isnothing(name) && throw(ArgumentError("Stage with $(number) not defined"))
    return get_stage(s, name)
end

get_stages_quantity(s::Simulation) = s.internal.stages_count

function get_simulation_time(s::Simulation, stage_number::Int)
    return s.internal.date_ref[stage_number]
end

get_ini_cond_chronology(s::Simulation) = s.sequence.ini_cond_chronology
get_stage_name(s::Simulation, stage::Stage) = get_stage_name(s.sequence, stage)
get_name(s::Simulation) = s.name
get_simulation_folder(s::Simulation) = s.simulation_folder
get_results_folder(s::Simulation) = joinpath(s.simulation_folder, s.name)
get_execution_order(s::Simulation) = s.sequence.execution_order
get_current_execution_index(s::Simulation) = s.sequence.current_execution_index

function get_stage_cache_definition(s::Simulation, stage::String)
    caches = s.sequence.cache
    cache_ref = Array{AbstractCache, 1}()
    for stage_names in keys(caches)
        if stage in stage_names
            push!(cache_ref, caches[stage_names])
        end
    end
    if isempty(cache_ref)
        return nothing
    end
    return cache_ref
end

function get_cache(s::Simulation, key::CacheKey)
    c = get(s.internal.simulation_cache, key, nothing)
    isnothing(c) &&
    throw(ArgumentError("Cache with key $(key) not present in the simulation"))
    return c
end

function get_cache(
    s::Simulation,
    ::Type{T},
    ::Type{D},
) where {T <: AbstractCache, D <: PSY.Device}
    return get_cache(s, CacheKey(T, D))
end

function _check_forecasts_sequence(sim::Simulation)
    for (stage_number, stage_name) in sim.sequence.order
        stage = get_stage(sim, stage_name)
        resolution = PSY.get_forecasts_resolution(get_sys(stage))
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
    if isempty(sim.sequence.feedforward_chronologies)
        @info("No Feedforward Chronologies defined")
    end
    for (key, chron) in sim.sequence.feedforward_chronologies
        check_chronology!(sim, key, chron)
    end
    return
end

function _assign_feedforward_chronologies(sim::Simulation)
    for (key, chron) in sim.sequence.feedforward_chronologies
        to_stage = get_stage(sim, key.second)
        to_stage_interval = IS.time_period_conversion(get_stage_interval(sim, key.second))
        from_stage_number = find_key_with_value(sim.sequence.order, key.first)
        if isempty(from_stage_number)
            throw(ArgumentError("Stage $(key.first) not specified in the order dictionary"))
        end
        for stage_number in from_stage_number
            to_stage.internal.chronolgy_dict[stage_number] = chron
            from_stage = get_stage(sim, stage_number)
            from_stage_resolution =
                IS.time_period_conversion(PSY.get_forecasts_resolution(from_stage.sys))
            # This line keeps track of the executions of a stage relative to other stages.
            # This might be needed in the future to run multiple stages. For now it is disabled
            #to_stage.internal.synchronized_executions[stage_number] =
            #Int(from_stage_resolution / to_stage_interval)
        end
    end
    return
end

function _prepare_workspace(base_name::AbstractString, folder::AbstractString)
    global_path = joinpath(folder, "$(base_name)")
    !isdir(global_path) && mkpath(global_path)
    _sim_path = replace_chars("$(round(Dates.now(), Dates.Minute))", ":", "-")
    simulation_path = joinpath(global_path, _sim_path)
    raw_output = joinpath(simulation_path, "raw_output")
    mkpath(raw_output)
    models_json_ouput = joinpath(simulation_path, "models_json")
    mkpath(models_json_ouput)
    results_path = joinpath(simulation_path, "results")
    mkpath(results_path)

    return raw_output, models_json_ouput, results_path
end

function _get_simulation_initial_times!(sim::Simulation)
    k = keys(sim.sequence.order)
    k_size = length(k)
    @assert k_size == maximum(k)

    stage_initial_times = Dict{Int, Vector{Dates.DateTime}}()
    time_range = Vector{Dates.DateTime}(undef, 2)
    sim_ini_time = get_initial_time(sim)
    for (stage_number, stage_name) in sim.sequence.order
        stage_system = sim.stages[stage_name].sys
        PSY.check_forecast_consistency(stage_system)
        interval = PSY.get_forecasts_interval(stage_system)
        horizon = get_stage_horizon(get_sequence(sim), stage_name)
        seq_interval = get_stage_interval(get_sequence(sim), stage_name)
        if PSY.are_forecasts_contiguous(stage_system)
            stage_initial_times[stage_number] =
                PSY.generate_initial_times(stage_system, seq_interval, horizon)
            if isempty(stage_initial_times[stage_number])
                throw(IS.ConflictingInputsError("Simulation interval ($seq_interval) and
                        forecast interval ($interval) definitions are not compatible"))
            end
        else
            stage_initial_times[stage_number] = PSY.get_forecast_initial_times(stage_system)
            interval = PSY.get_forecasts_interval(stage_system)
            if interval != seq_interval
                throw(IS.ConflictingInputsError("Simulation interval ($seq_interval) and
                        forecast interval ($interval) definitions are not compatible"))
            end
            for (ix, element) in enumerate(stage_initial_times[stage_number][1:(end - 1)])
                if !(element + interval == stage_initial_times[stage_number][ix + 1])
                    throw(IS.ConflictingInputsError("The sequence of forecasts is invalid"))
                end
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

    return stage_initial_times
end

function _attach_feedforward!(sim::Simulation, stage_name::String)
    stage = get(sim.stages, stage_name, nothing)
    feedforward = filter(p -> (p.first[1] == stage_name), sim.sequence.feedforward)
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
    for (stage_number, stage_name) in sim.sequence.order
        stage = sim.stages[stage_name]
        execution_counts = get_executions(stage)
        @assert length(findall(x -> x == stage_number, sim.sequence.execution_order)) ==
                execution_counts
        forecast_count = length(stage_initial_times[stage_number])
        if get_steps(sim) * execution_counts > forecast_count
            throw(IS.ConflictingInputsError("The number of available time series ($(forecast_count)) is not enough to perform the
            desired amount of simulation steps ($(sim.steps*stage.internal.execution_count))."))
        end
    end
    return
end

function _check_required_ini_cond_caches(sim::Simulation)
    for (stage_number, stage_name) in sim.sequence.order
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
    isnothing(caches) && return
    stage = get_stage(sim, stage_name)
    _set_internal_caches(sim.internal, stage, caches)
    return
end

function _build_stages!(sim::Simulation)
    for (stage_number, stage_name) in sim.sequence.order
        TimerOutputs.@timeit BUILD_SIMULATION_TIMER "Build Stage $(stage_name)" begin
            @info("Building Stage $(stage_number)-$(stage_name)")
            horizon = get_stage_horizon(get_sequence(sim), stage_name)
            stage = get_stage(sim, stage_name)
            stage_interval = get_stage_interval(get_sequence(sim), stage_name)
            initial_time = get_initial_time(sim)
            build!(stage, initial_time, horizon, stage_interval)
            _populate_caches!(sim, stage_name)
            sim.internal.date_ref[stage_number] = initial_time
        end
    end
    _check_required_ini_cond_caches(sim)
    return
end

function _build_stage_paths!(sim::Simulation, system_to_file::Bool)
    for (stage_number, stage_name) in sim.sequence.order
        stage = sim.stages[stage_name]
        stage_path = joinpath(sim.internal.models_dir, "stage_$(stage_name)_model")
        mkpath(stage_path)
        _write_psi_container(
            stage.internal.psi_container,
            joinpath(stage_path, "$(stage_name)_optimization_model.json"),
        )
        system_to_file &&
        PSY.to_json(stage.sys, joinpath(stage_path, "$(stage_name)_sys_data.json"))
    end
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

    mkpath(get_results_folder(sim))
end

# TODO: Add DocString
@doc raw"""
        build!(sim::Simulation)
"""
function build!(sim::Simulation)
    TimerOutputs.reset_timer!(BUILD_SIMULATION_TIMER)
    TimerOutputs.@timeit BUILD_SIMULATION_TIMER "Build Simulation" begin
        _check_forecasts_sequence(sim)
        _check_feedforward_chronologies(sim)
        _check_folder(sim)
        for name in sim.recorders
            IS.register_recorder!(name; directory = get_results_folder(sim))
        end
        sim.internal = SimulationInternal(sim.steps, keys(sim.sequence.order))
        stage_initial_times = _get_simulation_initial_times!(sim)
        for (stage_number, stage_name) in sim.sequence.order
            stage = get_stage(sim, stage_name)
            if isnothing(stage)
                throw(IS.ConflictingInputsError("Stage $(stage_name) not found in the stages definitions"))
            end
            stage_interval = get_stage_interval(sim, stage_name)
            stage.internal.executions =
                Int(get_step_resolution(sim.sequence) / stage_interval)
            stage.internal.number = stage_number
            _attach_feedforward!(sim, stage_name)
        end
        _assign_feedforward_chronologies(sim)
        _check_steps(sim, stage_initial_times)
        _build_stages!(sim)
        sim.internal.compiled_status = true
    end
    @info ("\n$(BUILD_SIMULATION_TIMER)\n")
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
    chronology::IntraStageChronology,
    sim::Simulation,
)
    for ic in initial_conditions
        name = device_name(ic)
        interval_chronology =
            get_stage_interval_chronology(sim.sequence, get_stage_name(sim, stage))
        var_value =
            get_stage_variable(interval_chronology, (stage => stage), name, ic.update_ref)
        if isnothing(ic.cache_type)
            cache = nothing
        else
            cache = get_cache(sim, ic.cache_type, ini_cond_key.device_type)
        end
        quantity = calculate_ic_quantity(ini_cond_key, ic, var_value, cache)
        PJ.fix(ic.value, quantity)
        @IS.record :simulation InitialConditionUpdateEvent(
            ini_cond_key,
            ic,
            quantity,
            get_number(stage),
        )
    end
end

""" Updates the initial conditions of the stage"""
function initial_condition_update!(
    stage::Stage,
    ini_cond_key::ICKey,
    initial_conditions::Vector{InitialCondition},
    chronology::InterStageChronology,
    sim::Simulation,
)
    execution_index = get_execution_order(sim)
    for ic in initial_conditions
        name = device_name(ic)
        current_ix = get_current_execution_index(sim)
        source_stage_ix = current_ix == 1 ? length(execution_index) : current_ix - 1
        source_stage = get_stage(sim, execution_index[source_stage_ix])
        source_stage_name = get_stage_name(sim, source_stage)
        interval_chronology = get_stage_interval_chronology(sim.sequence, source_stage_name)
        var_value = get_stage_variable(
            interval_chronology,
            (source_stage => stage),
            name,
            ic.update_ref,
        )
        if isnothing(ic.cache_type)
            cache = nothing
        else
            cache = get_cache(sim, ic.cache_type, ini_cond_key.device_type)
        end
        quantity = calculate_ic_quantity(ini_cond_key, ic, var_value, cache)
        PJ.fix(ic.value, quantity)
        @IS.record :simulation InitialConditionUpdateEvent(
            ini_cond_key,
            ic,
            quantity,
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
    key::CacheKey{TimeStatusChange, D},
    stage::Stage,
) where {D <: PSY.Device}
    c = get_cache(sim, key)
    increment = get_increment(sim, stage, c)
    variable = get_variable(stage.internal.psi_container, c.ref)
    for t in 1:get_end_of_interval_step(stage), name in variable.axes[1]
        device_status = JuMP.value(variable[name, t])
        @debug name, device_status
        if c.value[name][:status] == device_status
            c.value[name][:count] += increment
            @debug("Cache value TimeStatus for device $name set to $device_status and count to $(c.value[name][:count])")
        else
            c.value[name][:status] != device_status
            c.value[name][:count] = increment
            c.value[name][:status] = device_status
            @debug("Cache value TimeStatus for device $name set to $device_status and count to 1.0")
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
    key::CacheKey{StoredEnergy, D},
    stage::Stage,
) where {D <: PSY.Device}
    c = get_cache(sim, key)
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
    devices = PSY.get_components(T, stage.sys)
    initial_forecast_time = get_simulation_time(sim, get_number(stage))
    horizon = length(model_time_steps(stage.internal.psi_container))
    for d in devices
        forecast = PSY.get_forecast(
            PSY.Deterministic,
            d,
            initial_forecast_time,
            get_accessor_func(param_reference),
            horizon,
        )
        ts_vector = TS.values(PSY.get_data(forecast))
        device_name = PSY.get_name(d)
        for (ix, val) in enumerate(get_parameter_array(container)[device_name, :])
            value = ts_vector[ix]
            JuMP.fix(val, value)
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
    for (k, ref) in stage.internal.chronolgy_dict
        feedforward_update(ref, param_reference, param_array, stage, get_stage(sim, k))
    end

    return
end

function _update_initial_conditions!(stage::Stage, sim::Simulation)
    ini_cond_chronology = sim.sequence.ini_cond_chronology
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
) where {M <: AbstractOperationsProblem}
    _update_stage!(stage, sim)
    return
end

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
execute!!(sim::Simulation; kwargs...)
```
"""

function execute!(sim::Simulation; kwargs...)
    if sim.internal.reset
        sim.internal.reset = false
    elseif sim.internal.reset == false
        error("Re-build the simulation")
    end
    system_to_file = get(kwargs, :system_to_file, true)
    isnothing(sim.internal) &&
    error("Simulation not built, build the simulation to execute")
    TimerOutputs.reset_timer!(RUN_SIMULATION_TIMER)
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execute Simulation" begin
        name = get_name(sim)
        folder = get_simulation_folder(sim)
        sim.internal.raw_dir, sim.internal.models_dir, sim.internal.results_dir =
            _prepare_workspace(name, folder)
        _build_stage_paths!(sim, system_to_file)
        execution_order = get_execution_order(sim)
        for step in 1:get_steps(sim)
            TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execution Step $(step)" begin
                println("Executing Step $(step)")
                @IS.record :simulation_states SimulationStepEvent(step, "start")
                for (ix, stage_number) in enumerate(execution_order)
                    @IS.record :simulation_states SimulationStageEvent(
                        step,
                        stage_number,
                        "start",
                    )
                    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Execution Stage $(stage_number)" begin
                        # TODO: implement some efficient way of indexing with stage name.
                        stage = get_stage(sim, stage_number)
                        stage_name = get_stage_name(sim, stage)
                        stage_interval = get_stage_interval(sim, stage_name)
                        run_name = "step-$(step)-stage-$(stage_name)"
                        sim.internal.current_time = sim.internal.date_ref[stage_number]
                        sim.sequence.current_execution_index = ix
                        @info "Starting run $run_name $(sim.internal.current_time)"
                        raw_results_path = joinpath(
                            sim.internal.raw_dir,
                            run_name,
                            replace_chars("$(sim.internal.current_time)", ":", "-"),
                        )
                        mkpath(raw_results_path)
                        # Is first run of first stage? Yes -> don't update stage
                        TimerOutputs.@timeit RUN_SIMULATION_TIMER "Update Stage $(stage_number)" begin
                            !(step == 1 && ix == 1) && update_stage!(stage, sim)
                        end
                        TimerOutputs.@timeit RUN_SIMULATION_TIMER "Run Stage $(stage_number)" begin
                            run_stage(stage, sim.internal.current_time, raw_results_path)
                        end
                        TimerOutputs.@timeit RUN_SIMULATION_TIMER "Update Cache $(stage_number)" begin
                            _update_caches!(sim, stage)
                        end
                        if warm_start_enabled(stage)
                            TimerOutputs.@timeit RUN_SIMULATION_TIMER "Warm Start $(stage_number)" begin
                                _apply_warm_start!(stage)
                            end
                        end
                        sim.internal.run_count[step][stage_number] += 1
                        sim.internal.date_ref[stage_number] += stage_interval
                    end
                    @IS.record :simulation_states SimulationStageEvent(
                        step,
                        stage_number,
                        "done",
                    )
                end
                @IS.record :simulation_states SimulationStepEvent(step, "done")
            end
        end
        sim_results = SimulationResultsReference(sim)
    end

    @info ("\n$(RUN_SIMULATION_TIMER)\n")
    serialize_sim_output(sim_results)
    for name in sim.recorders
        IS.unregister_recorder!(name)
    end
    return sim_results
end

struct SimulationSerializationWrapper
    steps::Int
    stages::Dict{String, StageSerializationWrapper}
    initial_time::Union{Nothing, Dates.DateTime}
    sequence::Union{Nothing, SimulationSequence}
    simulation_folder::String
    name::String
    recorders::Vector{Symbol}
end

"""
    serialize(simulation::Simulation, path = ".")

Serialize the simulation to a directory in path.

Return the serialized simulation directory name that is created.

# Arguments
- `simulation::Simulation`: simulation to serialize
- `path = "."`: path in which to create the serialzed directory
- `force = false`: If true, delete the directory if it already exists. Otherwise, it will
   throw an exception.
"""
function serialize(simulation::Simulation; path = ".", force = false)
    directory = joinpath(path, "simulation-$(simulation.name)")
    stages = Dict{String, StageSerializationWrapper}()

    orig = pwd()
    if isdir(directory) || ispath(directory) && !force
        throw(ArgumentError("$directory already exists. Please delete it or pass force = true."))
    end
    rm(directory, recursive = true, force = true)
    mkdir(directory)
    cd(directory)

    try
        for (key, stage) in simulation.stages
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
        simulation.steps,
        stages,
        simulation.initial_time,
        simulation.sequence,
        simulation.simulation_folder,
        simulation.name,
        simulation.recorders,
    )
    Serialization.serialize(filename, obj)
    @info "Serialized simulation" simulation.name directory
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
            recorders = obj.recorders,
        )
        build!(sim)
        return sim
    finally
        cd(orig)
    end
end
