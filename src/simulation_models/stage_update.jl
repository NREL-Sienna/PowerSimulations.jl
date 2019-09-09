"""Updates the forecast parameter value"""
function parameter_update!(param_reference::UpdateRef{T},
                           param_array::JuMPParamArray,
                           stage_number::Int64,
                           sim::Simulation) where T <: PSY.Component

    forecasts = PSY.get_component_forecasts(T, sim.stages[stage_number].model.sys,
                                               sim.ref.date_ref[stage_number])
    for forecast in forecasts
        device = PSY.get_forecast_component_name(forecast)
        for (ix, val) in enumerate(param_array[device,:])
            value = PSY.get_forecast_value(forecast, ix)
            JuMP.fix(val, value)
        end
    end

    return

end

function feedforward_update(::Type{Synchronize},
                             param_reference::UpdateRef{JuMP.VariableRef},
                             param_array::JuMPParamArray,
                             to_stage::_Stage,
                             from_stage::_Stage)

    variable = var(from_stage.model.canonical, param_reference.access_ref)
    for device_name in axes(variable)[1]
        val = JuMP.value(variable[device_name, to_stage.execution_count + 1])
        PJ.fix(param_array[device_name], val)
    end

    return

end

function feedforward_update(::Type{Sequential},
                             param_reference::UpdateRef{JuMP.VariableRef},
                             param_array::JuMPParamArray,
                             to_stage::_Stage,
                             from_stage::_Stage)

    variable = var(from_stage.model.canonical, param_reference.access_ref)

    for device_name in axes(variable)[1]
        val = JuMP.value(variable[device_name, end])
        PJ.fix(param_array[device_name], val)
    end

    return

end

function feedforward_update(::Type{RecedingHorizon},
                            param_reference::UpdateRef{JuMP.VariableRef},
                            param_array::JuMPParamArray,
                            to_stage::_Stage,
                            from_stage::_Stage)

    variable = var(from_stage.model.canonical, param_reference.access_ref)

    for device_name in axes(variable)[1]
        val = JuMP.value(variable[device_name, 1])
        PJ.fix(param_array[device_name], val)
    end

    return

end

"""Updates the forecast parameter value"""
function parameter_update!(param_reference::UpdateRef{JuMP.VariableRef},
                           param_array::JuMPParamArray,
                           stage_number::Int64,
                           sim::Simulation)

    chronology_ref = sim.stages[stage_number].chronology_ref
    current_stage = sim.stages[stage_number]

    for (k, ref) in chronology_ref
        feedforward_update(ref, param_reference, param_array, current_stage, sim.stages[k])
    end

    return

end

function _initial_condition_update!(::Type{Sequential},
                                    ini_cond_array,
                                    to_stage::_Stage,
                                    from_stage::_Stage)

    for ic in ini_cond_array
        variable = var(from_stage.model.canonical, ic.access_ref)
        device_name = ic.device.name
        step = axes(variable)[2][end]
        var_value = JuMP.value(variable[device_name, step])
        PJ.fix(ic.value, var_value)
    end

    return

end

function _initial_condition_update!(::Type{RecedingHorizon},
                                    ini_cond_array,
                                    to_stage::_Stage,
                                    from_stage::_Stage)

    for ic in ini_cond_array
        variable = var(from_stage.model.canonical, ic.access_ref)
        device_name = ic.device.name
        step = axes(variable)[2][1]
        var_value = JuMP.value(variable[device_name, step])
        PJ.fix(ic.value, var_value)
    end

    return

end

function _initial_condition_update!(::Nothing,
                                    ini_cond_array,
                                    to_stage::_Stage,
                                    from_stage::_Stage)
    return
end


function intial_condition_update!(ini_cond_array,
                                  stage_number::Int64,
                                  step::Int64,
                                  sim::Simulation)

    chronology_ref = sim.stages[stage_number].ini_cond_chron
    current_stage = sim.stages[stage_number]
    #checks if current stage is the first in the step and the execution is the first to
    # look backwards on the previous step
    intra_step_update = (stage_number == 1 && current_stage.execution_count == 0)
    #checks if current execution is the first execution to look into the previuous stage
    intra_stage_update = (stage_number > 1 && current_stage.execution_count == 0)
    #checks that the current run and stage ininital conditions is based on the current results
    inner_stage_update = (stage_number > 1 && current_stage.execution_count > 0)
    # makes the update based on the last stage.
    if intra_step_update
        from_stage = sim.stages[end]
    # Updates the next stage in the same step
    elseif intra_stage_update
        from_stage = sim.stages[stage_number-1]
    # Update is done on the current stage
    elseif inner_stage_update
        from_stage = current_stage
    else
        error("Condition not implemented")
    end

    _initial_condition_update!(chronology_ref, ini_cond_array, current_stage, from_stage)

    return

end

function update_stage!(stage::_Stage, step::Int64, sim::Simulation)
    # Is first run of first stage? Yes -> do nothing
    (step == 1 && stage.execution_count == 0) && return

    for (k, v) in stage.model.canonical.parameters
        parameter_update!(k, v, stage.key, sim)
    end

    # Set initial conditions of the stage I am about to run.
    for (k, v) in stage.model.canonical.initial_conditions
        intial_condition_update!(v, stage.key, step, sim)
    end

    return

end
