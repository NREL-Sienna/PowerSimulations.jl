function _prepare_workspace!(ref::SimulationRef, base_name::String, folder::String)

    !isdir(folder) && error("Specified folder is not valid")

    cd(folder)
    global_path = joinpath(folder, "$(base_name)")
    isdir(global_path) && mkpath(global_path)
    _sim_path = replace_char("$(round(Dates.now(),Dates.Minute))-$(base_name)", ":", "-")
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

    for (k,v) in stages

        forecast_count = length(PSY.get_forecast_initial_times(v.sys))

        if steps*v.execution_count > forecast_count #checks that there are enough time series to run
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

function _populate_cache!(cache_vector::Vector{<:AbstractCache}, op_model::OperationModel)

    for cache in cache_vector
        build_cache!(cache, op_model)
    end

    return
end

function _build_stages(sim_ref::SimulationRef,
                       stages::Dict{Int64, Stage},
                       verbose::Bool = true;
                       kwargs...)

    system_to_file = get(kwargs, :system_to_file, true)
    mod_stages = Vector{_Stage}(undef, length(stages))

    for (k, v) in stages
        verbose && @info("Building Stage $(k)")
        op_mod = OperationModel(DefaultOpModel, v.model, v.sys;
                                optimizer = v.optimizer,
                                parameters = true,
                                verbose = verbose,
                                kwargs...)
        stage_path = joinpath(sim_ref.models,"stage_$(k)_model")
        mkpath(stage_path)
        write_op_model(op_mod, joinpath(stage_path, "optimization_model.json"))
        system_to_file && IS.to_json(v.sys, joinpath(stage_path ,"sys_data.json"))
        _populate_cache!(v.cache, op_mod)
        mod_stages[k] = _Stage(k, op_mod, v.execution_count, v.chronology_ref, v.cache)
        sim_ref.date_ref[k] = PSY.get_forecast_initial_times(v.sys)[1]
    end

    return mod_stages

end

function _feedforward_rule_check(::Type{T},
                              stage_number_from::Int64,
                              from_stage::Stage,
                              stage_number_to::Int64,
                              to_stage::Stage,) where T <: Chronology

    error("feedforward Model $(T) not implemented")

    return

end


function _feedforward_rule_check(::Type{Synchronize},
                              stage_number_from::Int64,
                              from_stage::Stage,
                              stage_number_to::Int64,
                              to_stage::Stage)

    #Don't check for same Stage.
    stage_number_from == stage_number_to && return

    from_stage_count = PSY.get_forecasts_horizon(from_stage.sys)
    to_stage_count = get_execution_count(to_stage)

    if from_stage_count < to_stage_count
        error("The number of steps in stage $(stage_number_from) is insufficient
               to synchronize with stage $(stage_number_to)")
    end

    if (from_stage_count % to_stage_count) != 0
        error("The number of steps in stage $(stage_number_to) needs to be a
               mutiple of the horizon length of stage $(stage_number_from) to
               use Synchronize")
    end

    return

end

function _feedforward_rule_check(::Type{Sequential},
                              stage_number_from::Int64,
                              from_stage::Stage,
                              stage_number_to::Int64,
                              to_stage::Stage)

    return

end

function _feedforward_rule_check(::Type{RecedingHorizon},
                                stage_number_from::Int64,
                                from_stage::Stage,
                                stage_number_to::Int64,
                                to_stage::Stage)

    return

end

function _check_chronology_ref(stages::Dict{Int64, Stage})

    for (stage_number,stage) in stages
        for (k, v) in stage.chronology_ref
            k < 1 && continue
            _feedforward_rule_check(v, k, stages[k], stage_number, stage)
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
    _prepare_workspace!(sim_ref, base_name, simulation_folder)

    return dates, validation, _build_stages(sim_ref, stages, verbose = verbose; kwargs...)

end
