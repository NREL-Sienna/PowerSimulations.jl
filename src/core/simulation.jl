mutable struct SimulationInternal
    raw_dir::Union{String, Nothing}
    models_dir::Union{String, Nothing}
    results_dir::Union{String, Nothing}
    stages_count::Int64
    run_count::Dict{Int64, Dict{Int64, Int64}}
    date_ref::Dict{Int64, Dates.DateTime}
    date_range::NTuple{2, Dates.DateTime} #Inital Time of the first forecast and Inital Time of the last forecast
    current_time::Dates.DateTime
    reset::Bool
    compiled_status::Bool
end

function SimulationInternal(steps::Int64, stages_keys::Base.KeySet)
    count_dict = Dict{Int64, Dict{Int64, Int64}}()

    for s in 1:steps
        count_dict[s] = Dict{Int64, Int64}()
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
        Dict{Int64, Dates.DateTime}(),
        (Dates.now(), Dates.now()),
        Dates.now(),
        true,
        false
    )
end

mutable struct Simulation
    steps::Int64
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
    step_resolution = IS.time_period_conversion(step_resolution)
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
get_sequence(s::Simulation) = s.sequence
get_steps(s::Simulation) = s.steps
get_date_range(s::Simulation) = s.internal.date_range
get_stage(s::Simulation, name::String) = get(s.stages, name, nothing)
get_stage(s::Simulation, number::Int64) = get(s.stages, s.sequence.order[number], nothing)
get_last_stage(s::Simulation) = get_stage(s, s.internal.stages_count)
function get_simulation_time(s::Simulation, stage_number::Int64)
    return s.internal.date_ref[stage_number]
end
get_ini_cond_chronology(s::Simulation, number::Int64) = get(s.sequence.ini_cond_chronology, s.sequence.order[number], nothing)
get_name(s::Simulation, stage::Stage) = get(s.sequence.order, get_number(stage), nothing)


function _check_sequence(sim::Simulation)
    for (stage_number,stage_name) in sim.sequence.order
        stage = get_stage(sim, stage_name)
        resolution = PSY.get_forecasts_resolution(get_sys(stage))
        horizon = get_horizon(get_sequence(sim), stage_name)
        interval = get_interval(get_sequence(sim), stage_name)
        horizon_time = resolution * horizon
        if horizon_time < interval
            throw(IS.ConflictingInputsError("horizon ($horizon_time) is 
                                shorter than interval ($interval) for $stage_name"))
        end
    end
end

function add_cache!(feedforward::AbstractAffectFeedForward, sim::Simulation, 
                            stage::Stage, 
                            device_model::DeviceModel{T, AbstractDeviceFormulation}) where {
                                T<:PSY.StaticInjection}

    cache = add_feedforward_cache!(feedforward, T)
    sequence = get_sequence(sim)
    stage_name = get_name(sim, stage) 
    if haskey(sequence.cache, stage_name)
        cache_vector = sequence.cache[stage_name]
    else
        cache_vector = Vector{AbstractCache}()
    end
    push!(cache_vector, cache)
    sequence.cache[stage_name] = cache_vector
    return
end

function _build_chronology_map(sim::Simulation)
    for (stage_number,stage_name) in sim.sequence.order
        stage_number == 1 && continue
        stage = get_stage(sim, stage_name)
        previous_stage = get_stage(sim, stage_number - 1)
        executions = get_executions(stage)
        horizon = get_horizon(get_sequence(sim), stage_name)
        map = get_variable_map(stage)
        interval = get_interval(get_sequence(sim), stage_name)
        resolution = PSY.get_forecasts_resolution(get_sys(stage))
        prev_resolution = PSY.get_forecasts_resolution(get_sys(previous_stage))
        sub_periods = prev_resolution/resolution
        for e in 1:executions
            for t in 1:horizon
                elapsed_time = ((interval / resolution) * (e-1)) + t - 1
                map[(e, t)] = ((sub_periods + elapsed_time) - (elapsed_time % sub_periods)) / sub_periods
            end
        end
    end
    return
end


function _check_chronologies(sim::Simulation)
    for (key, chron) in sim.sequence.intra_stage_chronologies
        check_chronology(chron, key, sim.sequence.horizons)
    end
    return
end

function _assign_chronologies(sim::Simulation)
    for (key, chron) in sim.sequence.intra_stage_chronologies
        stage = get_stage(sim, key.second)
        from_stage_number = find_key_with_value(sim.sequence.order, key.first)
        isempty(from_stage_number) && throw(ArgumentError("Stage $(key.first) not specified in the order dictionary"))
        for stage_number in from_stage_number
            stage.internal.chronolgy_dict[stage_number] = chron
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
    stage_initial_times = Dict{Int64, Vector{Dates.DateTime}}()
    time_range = Vector{Dates.DateTime}(undef, 2)
    
    for (stage_number, stage_name) in sim.sequence.order
        stage_system = sim.stages[stage_name].sys
        interval = PSY.get_forecasts_interval(stage_system)
        horizon = get_horizon(get_sequence(sim), stage_name)
        seq_interval = get_interval(get_sequence(sim), stage_name)
        if PSY.are_forecasts_contiguous(stage_system)
            stage_initial_times[stage_number] = PSY.generate_initial_times(stage_system, seq_interval, horizon)
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
            for (ix, element) in enumerate(stage_initial_times[stage_number][1:end-1])
                if !(element + interval == stage_initial_times[stage_number][ix+1])
                    throw(IS.ConflictingInputsError("The sequence of forecasts is invalid"))
                end
            end
        end
        stage_number == 1 && (time_range[1] = stage_initial_times[stage_number][1])
        (stage_number == k_size && (time_range[end] = stage_initial_times[stage_number][end]))
    end
    sim.internal.date_range = Tuple(time_range)

    if isnothing(get_initial_time(get_sequence(sim)))
        sim.sequence.initial_time = stage_initial_times[1][1]
        @warn("Initial time not defined as an argument, it will be infered from the data.
               Initial Simulation Time set to $(sim.sequence.initial_time)")
    end

    return stage_initial_times
end

function _attach_feed_forward!(sim::Simulation, stage_name::String)
    stage = get(sim.stages, stage_name, nothing)
    feed_forward = filter(p -> (p.first[1] == stage_name), sim.sequence.feed_forward)
    from_stage_num = get(sim.sequence.order, get_number(stage)-1, nothing)
    for (key, ff) in feed_forward
        #Note: key[1] = Stage name, key[2] = template field name, key[3] = device model key
        field_dict = getfield(stage.template, key[2])
        device_model = get(field_dict, key[3], nothing)
        isnothing(device_model) && throw(IS.ConflictingInputsError("Device model $(key[3]) not found in stage $(stage_name)"))
        device_model.feed_forward = ff
        if !isnothing(from_stage_num) && get_executions(get_stage(sim, from_stage_num)) > 1
            @info("Defined Simulation Sequence will use FeedFoward Cache")
            from_stage = get_stage(sim, from_stage_num)
            from_stage_device_model =  get(getfield(from_stage.template, key[2]), key[3], nothing)
            add_cache!(ff, sim, from_stage, from_stage_device_model)
        end
    end
    return
end

function _check_steps(sim::Simulation, stage_initial_times::Dict{Int64, Vector{Dates.DateTime}})
    for (stage_number, stage_name) in sim.sequence.order
        forecast_count = length(stage_initial_times[stage_number])
        stage = get(sim.stages, stage_name, nothing)
        if sim.steps*stage.internal.execution_count > forecast_count
            throw(IS.ConflictingInputsError("The number of available time series ($(forecast_count)) is not enough to perform the
                  desired amount of simulation steps ($(sim.steps*stage.internal.execution_count))."))
        end
    end
    return
end

function _populate_caches!(sim::Simulation, stage_name::String)
    caches = get(sim.sequence.cache, stage_name, nothing)
    isnothing(caches) && return
    cache_dict = (get_stage(sim, stage_name)).internal.cache_dict
    for c in caches
        cache_dict[CacheKey(c)] = c
        build_cache!(c, sim, stage_name)
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
        
        if PSY.are_forecasts_contiguous(stage.sys)
            sim.internal.date_ref[stage_number] = PSY.generate_initial_times(stage.sys,
                                                    get_interval(get_sequence(sim), stage_name),
                                                    get_horizon(get_sequence(sim), stage_name))[1]
        else
            sim.internal.date_ref[stage_number] = PSY.get_forecast_initial_times(stage.sys)[1]
        end
    end

    return
end

function _build_stage_paths!(sim::Simulation, verbose::Bool = true; kwargs...)
    system_to_file = get(kwargs, :system_to_file, true)
    for (stage_number, stage_name) in sim.sequence.order
        stage = get(sim.stages, stage_name, nothing)
        stage_path = joinpath(sim.internal.models_dir, "stage_$(stage_name)_model")
        mkpath(stage_path)
        _write_psi_container(stage.internal.psi_container,
                            joinpath(stage_path, "$(stage_name)_optimization_model.json"))
        system_to_file && PSY.to_json(stage.sys, joinpath(stage_path , "$(stage_name)_sys_data.json"))
    end
end

function _stage_execution_count(sim::Simulation, stage_name::String; kwargs...)
    execution_count = 0.0
    for (key, chron) in sim.sequence.intra_stage_chronologies
        if key.second == stage_name 
            to_stage_res =PSY.get_forecasts_resolution(get_sys(
                                    get_stage(sim, stage_name)))
            from_stage_res = PSY.get_forecasts_resolution(get_sys(
                                    get_stage(sim, key.first)))
            to_stage_horizon = get_horizon(get_sequence(sim), stage_name)
            to_stage_interval = get_interval(get_sequence(sim), stage_name)
            _count = (chron.from_periods*from_stage_res 
                    - to_stage_horizon*to_stage_res + to_stage_interval) /to_stage_interval
            if execution_count != 0.0
                if _count != execution_count
                    throw(IS.ConflictingInputsErrors("Stage $stage_name has two conflicting 
                                                    execution counts $_count != $execution_count"))
                end
            else
                execution_count = Int64(_count)
                @info("Stage $stage_name will have $execution_count execution in each step, 
                        as Synchronize.from_periods is set to $(chron.from_periods)")
            end
        end
        if key.first == stage_name 
            resolution = PSY.get_forecasts_resolution(get_sys(
                                get_stage(sim, stage_name)))
            interval = get_interval(get_sequence(sim), stage_name)
            _count = chron.from_periods*resolution/interval #TODO : Check/Dispatch on chronology  
            if execution_count != 0.0
                if _count != execution_count
                    throw(IS.ConflictingInputsErrors("Stage $stage_name has two 
                                                    conflicting execution counts $_count != $execution_count"))
                end
            else
                execution_count =Int64(_count)
                @info("Stage $stage_name will have $execution_count execution in each step, 
                        Synchronize($key).from_periods is set to $(chron.from_periods)")
            end
        end
    end
    return execution_count
end

function build!(sim::Simulation; verbose::Bool = false, kwargs...)
    _check_sequence(sim)
    _check_chronologies(sim)
    _check_folder(sim.simulation_folder)
    sim.internal = SimulationInternal(sim.steps, keys(sim.sequence.order))
    stage_initial_times = _get_simulation_initial_times!(sim)
    for (stage_number, stage_name) in sort(sim.sequence.order)
        stage = get(sim.stages, stage_name, nothing)
        stage_interval = sim.sequence.intervals[stage_name]
        executions = _stage_execution_count(sim, stage_name)
        stage.internal = StageInternal(stage_number, executions, 0, nothing)
        isnothing(stage) && throw(IS.ConflictingInputsError("Stage $(stage_name) not found in the stages definitions"))
        PSY.check_forecast_consistency(stage.sys)
        _attach_feed_forward!(sim, stage_name)
    end
    _assign_chronologies(sim)
    _build_chronology_map(sim)
    _check_steps(sim, stage_initial_times)
    _build_stages!(sim, verbose = verbose; kwargs...)
    sim.internal.compiled_status = true
    return
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
