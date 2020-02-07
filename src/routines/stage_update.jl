#########################TimeSeries Data Updating###########################################
function parameter_update!(
    param_reference::UpdateRef{T},
    container::ParameterContainer,
    stage::Stage,
    sim::Simulation,
) where {T<:PSY.Component}
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
        for (ix, val) in enumerate(container.array[device_name, :])
            value = ts_vector[ix]
            JuMP.fix(val, value)
        end
    end

    return
end

"""Updates the forecast parameter value"""
function parameter_update!(
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

#############################Interfacing Functions##########################################
function _update_caches!(stage::Stage)
    for cache in values(stage.internal.cache_dict)
        update_cache!(cache, stage)
    end

    return
end

function _intial_conditions_update!(
    initial_condition_key::ICKey,
    ini_cond_vector::Vector{InitialCondition},
    stage_number::Int64,
    step::Int64,
    sim::Simulation,
)
    ini_cond_chronolgy = nothing
    current_stage = get_stage(sim, stage_number)
    #checks if current stage is the first in the step and the execution is the first to
    # look backwards on the previous step
    intra_step_update = (stage_number == 1 && get_execution_count(current_stage) == 0)
    #checks if current execution is the first execution to look into the previuous stage
    intra_stage_update = (stage_number > 1 && get_execution_count(current_stage) == 0)
    #checks that the current run and stage ininital conditions is based on the current results
    inner_stage_update = (stage_number > 1 && get_execution_count(current_stage) > 0)
    # makes the update based on the last stage.
    if intra_step_update
        from_stage = get_last_stage(sim)
        ini_cond_chronolgy = get_ini_cond_chronology(sim, stage_number)
        # Updates the next stage in the same step. Uses the same chronology as intra_stage
    elseif intra_stage_update
        from_stage = get_stage(sim, stage_number - 1)
        ini_cond_chronolgy = current_stage.internal.chronolgy_dict[stage_number - 1]
        # Update is done on the current stage
    elseif inner_stage_update
        from_stage = current_stage
        ini_cond_chronolgy = get_ini_cond_chronology(sim, stage_number)
    else
        error("Condition not implemented")
    end
    initial_condition_update!(
        initial_condition_key,
        ini_cond_chronolgy,
        ini_cond_vector,
        current_stage,
        from_stage,
    )

    return
end

function update_stage!(
    stage::Stage{M},
    step::Int64,
    sim::Simulation,
) where {M<:AbstractOperationsProblem}
    # Is first run of first stage? Yes -> do nothing
    (step == 1 && get_number(stage) == 1 && get_execution_count(stage) == 0) && return
    for container in iterate_parameter_containers(stage.internal.psi_container)
        parameter_update!(container.update_ref, container, stage, sim)
    end

    _update_caches!(stage)

    # Set initial conditions of the stage I am about to run.
    for (k, v) in get_initial_conditions(stage.internal.psi_container)
        _intial_conditions_update!(k, v, get_number(stage), step, sim)
    end

    return
end
