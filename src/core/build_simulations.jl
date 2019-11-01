function _prepare_workspace!(ref::SimulationRef, base_name::AbstractString, folder::AbstractString)

    !isdir(folder) && error("Specified folder is not valid")
    global_path = joinpath(folder, "$(base_name)")
    !isdir(global_path) && mkpath(global_path)
    _sim_path = replace_chars("$(round(Dates.now(),Dates.Minute))", ":", "-")
    simulation_path = joinpath(global_path, _sim_path)
    raw_ouput = joinpath(simulation_path, "raw_output")
    mkpath(raw_ouput)
    models_json_ouput = joinpath(simulation_path, "models_json")
    mkpath(models_json_ouput)
    results_path = joinpath(simulation_path, "results")
    mkpath(results_path)

    ref.raw = raw_ouput
    ref.models = models_json_ouput
    ref.results = results_path

    return

end

function _validate_steps(stages::Dict{Int64, Stage}, steps::Int64)

    for (_, s) in stages

        forecast_count = length(PSY.get_forecast_initial_times(s.sys))

        if steps*s.execution_count > forecast_count #checks that there are enough time series to run
            error("The number of available time series is not enough to perform the
                   desired amount of simulation steps.")
        end

    end

    return

end

function _get_dates(stages::Dict{Int64, Stage})
    k = keys(stages)
    k_size = length(k)
    range = Vector{Dates.DateTime}(undef, 2)
    @assert k_size == maximum(k)

    for i in 1:k_size
        initial_times = PSY.get_forecast_initial_times(stages[i].sys)
        i == 1 && (range[1] = initial_times[1])
        interval = PSY.get_forecasts_interval(stages[i].sys)
        for (ix,element) in enumerate(initial_times[1:end-1])
            if !(element + interval == initial_times[ix+1])
                error("The sequence of forecasts is invalid")
            end
        end
        (i == k_size && (range[end] = initial_times[end]))
    end

    return Tuple(range), true

end

function _populate_cache!(stage::_Stage)

    for (k, cache) in stage.cache
        build_cache!(cache, stage.canonical)
    end

    return
end

function _build_stages(sim_ref::SimulationRef,
                       stages::Dict{Int64, Stage},
                       verbose::Bool = true;
                       kwargs...)

    system_to_file = get(kwargs, :system_to_file, true)
    mod_stages = Vector{_Stage}(undef, length(stages))
    for (key, stage) in stages
        verbose && @info("Building Stage $(key)")
        canonical = Canonical(stage.model.transmission,
                                   stage.sys,
                                   stage.optimizer;
                                   parameters = true)
        mod_stages[key] = _Stage(key,
                                stage.model,
                                stage.op_problem,
                                stage.sys,
                                canonical,
                                stage.optimizer,
                                stage.execution_count,
                                stage.chronology_ref,
                                stage.cache)
        _build!(mod_stages[key].canonical,
                          stage.model,
                          stage.sys;
                          parameters = true,
                          kwargs...)
        stage_path = joinpath(sim_ref.models,"stage_$(key)_model")
        mkpath(stage_path)
        _write_canonical(canonical, joinpath(stage_path, "optimization_model.json"))
        system_to_file && IS.to_json(stage.sys, joinpath(stage_path ,"sys_data.json"))
        _populate_cache!(mod_stages[key])
        sim_ref.date_ref[key] = PSY.get_forecast_initial_times(stage.sys)[1]
    end

    return mod_stages

end

function _feedforward_rule_check(::Type{T},
                              stage_number_from::Int64,
                              from_stage::Stage,
                              stage_number_to::Int64,
                              to_stage::Stage,) where T <: Chronology

    error("Feedforward Model $(T) not implemented")

    return

end


function _feedforward_rule_check(synch::Synchronize,
                                 stage_number_from::Int64,
                                 from_stage::Stage,
                                 stage_number_to::Int64,
                                 to_stage::Stage)

    #Don't check for same Stage.
    stage_number_from == stage_number_to && return

    from_stage_horizon = PSY.get_forecasts_horizon(from_stage.sys)
    to_stage_count = get_execution_count(to_stage)
    to_stage_synch = synch.to_steps
    from_stage_synch = synch.from_steps

    if from_stage_synch > from_stage_horizon
        error("The lookahead length $(from_stage_horizon) in stage is insufficient to synchronize with $(from_stage_synch) feedforward steps")
    end

    if to_stage_synch*from_stage_synch != to_stage_count
        error("The execution total in stage is inconsistent with a chronology
                of $(from_stage_synch) feedforward steps and $(to_stage_synch) runs. The expected
                number of executions is $(to_stage_synch*from_stage_synch)")
    end

    if (from_stage_horizon % from_stage_synch) != 0
        error("The number of feedforward steps $(from_stage_horizon) in stage
               needs to be a mutiple of the horizon length $(from_stage_horizon)
               of stage to use Synchronize with parameters ($(from_stage_synch), $(to_stage_synch))")
    end

    return

end

function _feedforward_rule_check(sync::Sequential,
                              stage_number_from::Int64,
                              from_stage::Stage,
                              stage_number_to::Int64,
                              to_stage::Stage)

    return

end

function _feedforward_rule_check(sync::RecedingHorizon,
                                stage_number_from::Int64,
                                from_stage::Stage,
                                stage_number_to::Int64,
                                to_stage::Stage)

    return

end

function _check_chronology_ref(stages::Dict{Int64, Stage})

    for (stage_number,stage) in stages
        for (key, chron) in stage.chronology_ref
            key < 1 && continue
            _feedforward_rule_check(chron, key, stages[key], stage_number, stage)
        end
    end

    return

end

function _build_simulation!(sim_ref::SimulationRef,
                          base_name::String,
                          steps::Int64,
                          stages::Dict{Int64, Stage},
                          simulation_folder::String;
                          verbose::Bool = false, kwargs...)


    _validate_steps(stages, steps)
    _check_chronology_ref(stages)
    dates, validation = _get_dates(stages)
    return dates, validation, _build_stages(sim_ref, stages, verbose = verbose; kwargs...)

end
