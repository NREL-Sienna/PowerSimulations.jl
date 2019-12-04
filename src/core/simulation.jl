mutable struct SimulationInternal
    raw_dir::String
    models_dir::String
    results_dir::String
    stages_count::Int64
    run_count::Dict{Int64, Dict{Int64, Int64}}
    date_ref::Dict{Int64, Dates.DateTime}
    date_range::NTuple{2, Dates.DateTime} #Inital Time of the first forecast and Inital Time of the last forecast
    current_time::Dates.DateTime
    reset::Bool
    compiled_status::Bool
end

function SimulationInternal(raw_dir::AbstractString,
                             models_dir::AbstractString,
                             results_dir::AbstractString,
                             steps::Int64,
                             stages_keys::Base.KeySet)
    count_dict = Dict{Int64, Dict{Int64, Int64}}()

    for s in 1:steps
        count_dict[s] = Dict{Int64, Int64}()
        for st in stages_keys
            count_dict[s][st] = 0
        end
    end

    return SimulationInternal(
        raw_dir,
        models_dir,
        results_dir,
        length(stages_keys),
        count_dict,
        Dict{Int64, Dates.DateTime}(),
        (Dates.now(), Dates.now()),
        Dates.now(),
        true,
        false
    )
end

mutable struct Simulation
    steps::Int64
    step_resolution::Dates.TimePeriod
    stages::Dict{String, Stage{<:AbstractOperationsProblem}}
    sequence::Union{Nothing, SimulationSequence}
    simulation_folder::String
    name::String
    internal::Union{Nothing, SimulationInternal}

    function Simulation(;name::String,
                        steps::Int64,
                        step_resolution::Dates.TimePeriod,
                        stages=Dict{String, Stage{AbstractOperationsProblem}}(),
                        stages_sequence=nothing,
                        simulation_folder::String,
                        verbose::Bool = false, kwargs...)
    new(
        steps,
        step_resolution,
        stages,
        stages_sequence,
        simulation_folder,
        name,
        nothing)
    end
end

################# accessor functions ####################
get_steps(s::Simulation) = s.steps
get_date_range(s::Simulation) = s.internal.date_range
get_stage(s::Simulation, name::String) = get(s.stages, name, nothing)
get_stage(s::Simulation, number::Int64) = get(s.stages, s.sequence.order[number], nothing)
get_last_stage(s::Simulation) = get_stage(s, s.internal.stages_count)
function get_simulation_time(s::Simulation, stage_number::Int64)
    return s.internal.date_ref[stage_number]
end


function _check_chronologies(sim::Simulation)
    for (key, chron) in sim.sequence.feed_forward_chronologies
        check_chronology(chron, key, sim.sequence.horizons)
    end
    return
end

function _prepare_workspace(base_name::AbstractString, folder::AbstractString)
    !isdir(folder) && throw(ArgumentError("Specified folder is not valid"))
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

function _check_dates!(sim::Simulation)
    k = keys(sim.sequence.order)
    k_size = length(k)
    range = Vector{Dates.DateTime}(undef, 2)
    @assert k_size == maximum(k)
    for (stage_number, stage_name) in sim.sequence.order
        stage_system = sim.stages[stage_name].sys
        initial_times = PSY.get_forecast_initial_times(stage_system)
        stage_number == 1 && (range[1] = initial_times[1])
        interval = PSY.get_forecasts_interval(stage_system)
        if interval != sim.sequence.intervals[stage_name]
            error("Simulation interval and forecast interval definitions are not compatible")
        end
        for (ix, element) in enumerate(initial_times[1:end-1])
            if !(element + interval == initial_times[ix+1])
                error("The sequence of forecasts is invalid")
            end
        end
        (stage_number == k_size && (range[end] = initial_times[end]))
    end
    sim.internal.date_range = Tuple(range)
    return
end

function _attach_feed_forward!(sim::Simulation, stage_name::String)
    stage = get(sim.stages, stage_name, nothing)
    feed_forward = filter(p->(p.first[1] == stage_name), sim.sequence.feed_forward)
    for (key, ff) in feed_forward
        #key[1] = Stage name, key[2] = template field name, key[3] = device model key
        field_dict = getfield(stage.template, key[2])
        device_model = get(field_dict, key[3], nothing)
        isnothing(device_model) && throw(ArgumentError("Device model $(key[3]) not found in stage $(stage_name)"))
        device_model.feed_forward = ff
    end
    return
end

function _check_steps(sim::Simulation, stage_initial_times::Dict{Int64, Vector{Dates.DateTime}})
    for (stage_number, stage_name) in sim.sequence.order
        forecast_count = length(stage_initial_times[stage_number])
        stage = get(sim.stages, stage_name, nothing)
        if sim.steps*stage.internal.execution_count > forecast_count
            error("The number of available time series is not enough to perform the
                   desired amount of simulation steps.")
        end
    end
    return
end

function _populate_caches!(sim::Simulation, stage_name::String)
    caches = get(sim.sequence.cache, stage_name, nothing)
    isnothing(caches) && return
    cache_dict = Dict{Type{<:AbstractCache}, AbstractCache}()
    for c in caches
        sim.stages[stage_name].internal.cache_dict[typeof(c)] = c
        #build_cache!(cache, sim.stages[stage_name].internal.psi_container)
    end
    return
end

function _build_stages!(sim::Simulation, verbose::Bool = true; kwargs...)
    system_to_file = get(kwargs, :system_to_file, true)
    for (stage_number, stage_name) in sim.sequence.order
        verbose && @info("Building Stage $(stage_number)-$(stage_name)")
        horizon = sim.sequence.horizons[stage_name]
        stage = get(sim.stages, stage_name, nothing)
        stage.internal.psi_container = PSIContainer(stage.template.transmission,
                                                    stage.sys,
                                                    stage.optimizer;
                                                    use_parameters = true,
                                                    initial_time = sim.sequence.initial_time,
                                                    horizon = horizon)
        _build!(stage.internal.psi_container,
                stage.template,
                stage.sys;
                kwargs...)
        _populate_caches!(sim, stage_name)
        stage_path = joinpath(sim.internal.models_dir, "stage_$(stage_name)_model")
        mkpath(stage_path)
        _write_psi_container(stage.internal.psi_container,
                             joinpath(stage_path, "$(stage_name)_optimization_model.json"))
        system_to_file && PSY.to_json(stage.sys, joinpath(stage_path , "$(stage_name)_sys_data.json"))
        sim.internal.date_ref[stage_number] = PSY.get_forecast_initial_times(stage.sys)[1]
    end

    return
end

function build!(sim::Simulation; verbose::Bool = false, kwargs...)
    _check_chronologies(sim)
    raw_dir, models_dir, results_dir = _prepare_workspace(sim.name, sim.simulation_folder)
    sim.internal = SimulationInternal(raw_dir, models_dir, results_dir, sim.steps, keys(sim.sequence.order))
    _check_dates!(sim)
    stage_initial_times = Dict{Int64, Vector{Dates.DateTime}}()
    if sim.sequence.initial_time == Dates.DateTime(0)
        sim.sequence.initial_time = PSY.get_forecast_initial_times(sim.stages[sim.sequence.order[1]].sys)[1]
        @warn("Initial time not defined as an argument, it will be infered from the data.
               Initial Simulation Time set to $(sim.sequence.initial_time)")
    end
    for (stage_number, stage_name) in sim.sequence.order
        stage = get(sim.stages, stage_name, nothing)
        stage_interval = sim.sequence.intervals[stage_name]
        executions = Int(sim.step_resolution/stage_interval)
        stage.internal = StageInternal(stage_number, executions, 0, nothing)
        isnothing(stage) && throw(ArgumentError("Stage $(stage_name) not found in the stages definitions"))
        PSY.check_forecast_consistency(stage.sys)
        # Check this is actually necessary
        if PSY.are_forecasts_contiguous(stage.sys)
            stage_initial_times[stage_number] = PSY.generate_initial_times(stage.sys,
                                                    stage_interval,
                                                    sim.sequence.horizons[stage_name],
                                                    initial_time = sim.sequence.initial_time)
        else
            stage_initial_times[stage_number] = PSY.get_forecast_initial_times(stage.sys)
        end
        _attach_feed_forward!(sim, stage_name)
    end
    _check_steps(sim, stage_initial_times)
    _build_stages!(sim, verbose = verbose; kwargs...)
    sim.internal.compiled_status = true
    return
end
