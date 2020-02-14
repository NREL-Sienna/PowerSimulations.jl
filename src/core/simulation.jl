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
    global_cache::Dict{String, Dict{<:Type{<:AbstractCache}, AbstractCache}}
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
        Dict{String, Dict{<:Type{<:AbstractCache}, AbstractCache}}()
    )
end

@doc raw"""
    Simulation(steps::Int
                stages::Dict{String, Stage{<:AbstractOperationsProblem}}
                sequence::Union{Nothing, SimulationSequence}
                simulation_folder::String
                name::String
                internal::Union{Nothing, SimulationInternal}
                )

""" # TODO: Add DocString
mutable struct Simulation
    steps::Int
    stages::Dict{String, Stage{<:AbstractOperationsProblem}}
    initial_time::Union{Nothing, Dates.DateTime}
    sequence::Union{Nothing, SimulationSequence}
    simulation_folder::String
    name::String
    internal::Union{Nothing, SimulationInternal}

    function Simulation(;
        name::String,
        steps::Int,
        stages = Dict{String, Stage{AbstractOperationsProblem}}(),
        stages_sequence = nothing,
        simulation_folder::String,
        kwargs...,
    )
        check_kwargs(kwargs, SIMULATION_KWARGS, "Simulation")
        initial_time = get(kwargs, :initial_time, nothing)
        new(steps, stages, initial_time, stages_sequence, simulation_folder, name, nothing)
    end
end

################# accessor functions ####################
get_initial_time(s::Simulation) = s.initial_time
get_sequence(s::Simulation) = s.sequence
get_steps(s::Simulation) = s.steps
get_date_range(s::Simulation) = s.internal.date_range
get_stage(s::Simulation, name::String) = get(s.stages, name, nothing)
get_stage_interval(s::Simulation, name::String) = get_stage_interval(s.sequence, name)
get_stage(s::Simulation, number::Int) = get(s.stages, s.sequence.order[number], nothing)
get_stages_quantity(s::Simulation) = s.internal.stages_count
function get_simulation_time(s::Simulation, stage_number::Int)
    return s.internal.date_ref[stage_number]
end
get_ini_cond_chronology(s::Simulation) = s.sequence.ini_cond_chronology
get_stage_name(s::Simulation, stage::Stage) = get_stage_name(s.sequence, stage)
get_name(s::Simulation) = s.name
get_simulation_folder(s::Simulation) = s.simulation_folder
get_execution_order(s::Simulation) = s.sequence.execution_order
get_current_execution_index(s::Simulation) = s.sequence.current_execution_index
get_stage_caches(s::Simulation, stage::String) = get(s.sequence.cache, stage, nothing)

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
    function find_val(d, value)
        for (k, v) in d
            v == value && return k
        end
        error("dict does not have value == $value")
    end

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
        @debug("Initial Simulation will be infered from the data.
               Initial Simulation Time set to $(sim.sequence.initial_time)")
    end

    return stage_initial_times
end

function _attach_feedforward!(sim::Simulation, stage_name::String)
    stage = get(sim.stages, stage_name, nothing)
    feedforward = filter(p -> (p.first[1] == stage_name), sim.sequence.feedforward)
    for (key, ff) in feedforward
        #Note: key[1] = Stage name, key[2] = template field name, key[3] = device model key
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
        receiving_stage = get_stage(sim, stage_name)
        for (k, v) in get_initial_conditions(receiving_stage.internal.psi_container)
            # No cache needed for the initial condition -> continue
            isnothing(v[1].cache_type) && continue
            c = nothing
            # Search other stages
            for source_stage in values(sim.stages)
                @show source_stage
                c = get_cache(source_stage, v[1].cache_type)
                break
            end
            if isnothing(c)
                throw(IS.ArgumentError("Cache $(v[1].cache_type) not defined for initial condition $(k.ic_type) in stage $receiving_stage "))
            end
            @debug "found cache $(v[1].cache_type) for initial condition $(k.ic_type)"
        end
    end
    return
end

function _populate_caches!(sim::Simulation, stage_name::String)
    caches = get_stage_caches(sim, stage_name)
    isnothing(caches) && return
    sim.internal.global_cache[stage_name] = Dict{Type{<:AbstractCache}, AbstractCache}()
    for c in caches
        sim.internal.global_cache[stage_name][typeof(c)] = c
        sim.stages[stage_name].internal.cache_dict[typeof(c)] = c
        build_cache!(sim.stages[stage_name].internal.psi_container, c)
    end
    return
end

function _build_stages!(sim::Simulation; kwargs...)
    system_to_file = get(kwargs, :system_to_file, true)
    for (stage_number, stage_name) in sim.sequence.order
        @info("Building Stage $(stage_number)-$(stage_name)")
        horizon = sim.sequence.horizons[stage_name]
        stage = get_stage(sim, stage_name)
        stage.internal.psi_container = PSIContainer(
            stage.template.transmission,
            stage.sys,
            stage.optimizer;
            use_parameters = true,
            initial_time = get_initial_time(sim),
            horizon = horizon,
        )
        _build!(stage.internal.psi_container, stage.template, stage.sys; kwargs...)
        _populate_caches!(sim, stage_name)
        if PSY.are_forecasts_contiguous(stage.sys)
            sim.internal.date_ref[stage_number] = PSY.generate_initial_times(
                stage.sys,
                get_stage_interval(get_sequence(sim), stage_name),
                get_stage_horizon(get_sequence(sim), stage_name),
            )[1]
        else
            sim.internal.date_ref[stage_number] =
                PSY.get_forecast_initial_times(stage.sys)[1]
        end
    end
    _check_required_ini_cond_caches(sim)
    return
end

function _build_stage_paths!(sim::Simulation; kwargs...)
    system_to_file = get(kwargs, :system_to_file, true)
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

function _check_folder(folder::String)
    !isdir(folder) && throw(IS.ConflictingInputsError("Specified folder is not valid"))
    try
        mkdir(joinpath(folder, "fake"))
        rm(joinpath(folder, "fake"))
    catch e
        throw(IS.ConflictingInputsError("Specified folder does not have write access [$e]"))
    end
end

@doc raw"""
        build!(sim::Simulation;
                kwargs...)

""" # TODO: Add DocString
function build!(sim::Simulation; kwargs...)
    check_kwargs(kwargs, SIMULATION_BUILD_KWARGS, "build!")
    if isnothing(sim.sequence) || isempty(sim.stages)
        throw(ArgumentError("The simulation object requires a valid definition of stages and SimulationSequence"))
    end
    _check_forecasts_sequence(sim)
    _check_feedforward_chronologies(sim)
    _check_folder(sim.simulation_folder)
    sim.internal = SimulationInternal(sim.steps, keys(sim.sequence.order))
    stage_initial_times = _get_simulation_initial_times!(sim)
    for (stage_number, stage_name) in sim.sequence.order
        stage = get_stage(sim, stage_name)
        if isnothing(stage)
            throw(IS.ConflictingInputsError("Stage $(stage_name) not found in the stages definitions"))
        end
        stage_interval = get_stage_interval(sim, stage_name)
        executions = Int(get_step_resolution(sim.sequence) / stage_interval)
        stage.internal = StageInternal(stage_number, executions, 0, nothing)
        _attach_feedforward!(sim, stage_name)
    end
    _assign_feedforward_chronologies(sim)
    _check_steps(sim, stage_initial_times)
    _build_stages!(sim; kwargs...)
    sim.internal.compiled_status = true
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
    chronology::IntraStageChronology,
    sim::Simulation,
)
    ini_cond_vector = get_initial_conditions(stage.internal.psi_container)[ini_cond_key]
    for ic in get_initial_conditions(stage.internal.psi_container)[ini_cond_key]
        name = device_name(ic)
        interval_chronology = get_stage_interval_chronology(sim, stage.name)
        var_value =
            get_stage_variable(interval_chronology, (stage => stage), name, ic.update_ref)
        cache = get_cache(stage, ic.cache_type)
        quantity = calculate_ic_quantity(ini_cond_key, ic, var_value, cache)
        PJ.fix(ic.value, quantity)
    end
    return
end

""" Updates the initial conditions of the stage"""
function initial_condition_update!(
    stage::Stage,
    ini_cond_key::ICKey,
    chronology::InterStageChronology,
    sim::Simulation,
)
    execution_index = get_execution_order(sim)
    ini_cond_vector = get_initial_conditions(stage.internal.psi_container)[ini_cond_key]
    for ic in ini_cond_vector
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
        cache = isnothing(ic.cache_type) ? nothing : get_cache(source_stage, ic.cache_type)
        quantity = calculate_ic_quantity(ini_cond_key, ic, var_value, cache)
        PJ.fix(ic.value, quantity)
    end

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
sim = Simulation("test", 7, stages, "/Users/folder")
execute!!(sim::Simulation; kwargs...)
```

# Accepted Key Words
- `constraints_duals::Vector{Symbol}`: if dual variables are desired in the
results, include a vector of the variable names to be included
"""

function execute!(sim::Simulation; kwargs...)
    if sim.internal.reset
        sim.internal.reset = false
    elseif sim.internal.reset == false
        error("Re-build the simulation")
    end

    isnothing(sim.internal) &&
    error("Simulation not built, build the simulation to execute")
    name = get_name(sim)
    folder = get_simulation_folder(sim)
    sim.internal.raw_dir, sim.internal.models_dir, sim.internal.results_dir =
        _prepare_workspace(name, folder)
    _build_stage_paths!(sim; kwargs...)
    execution_order = get_execution_order(sim)
    for step in 1:get_steps(sim)
        println("Executing Step $(step)")
        for (ix, stage_number) in enumerate(execution_order)
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
            !(step == 1 && ix == 1) && update_stage!(stage, step, sim)
            run_stage(stage, sim.internal.current_time, raw_results_path; kwargs...)
            sim.internal.run_count[step][stage_number] += 1
            sim.internal.date_ref[stage_number] += stage_interval
        end
    end
    constraints_duals = get(kwargs, :constraints_duals, nothing)
    sim_results = SimulationResultsReference(sim; constraints_duals = constraints_duals)
    return sim_results
end
