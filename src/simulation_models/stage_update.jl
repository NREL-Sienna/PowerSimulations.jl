"""Updates the forecast parameter value"""
function parameter_update!(param_reference::RefParam{T},
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
                             param_reference::RefParam{JuMP.VariableRef},
                             param_array::JuMPParamArray,
                             to_stage::_Stage,
                             from_stage::_Stage)

    variable = var(from_stage.model.canonical, param_reference.access_ref)

    for device_name in axes(variable)[1]
        val = JuMP.value(variable[device_name, to_stage.execution_count])
        PJ.fix(param_array[device_name], val)
    end

    return

end

function feedforward_update(::Type{RecedingHorizon},
                            param_reference::RefParam{JuMP.VariableRef},
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
function parameter_update!(param_reference::RefParam{JuMP.VariableRef},
                           param_array::JuMPParamArray,
                           stage_number::Int64,
                           sim::Simulation)

    feedforward_ref = sim.stages[stage_number].feedforward_ref
    current_stage = sim.stages[stage_number]

    for (k, ref) in feedforward_ref
        feedforward_update(ref, param_reference, param_array, current_stage, sim.stages[k])
    end

    return

end

function update_stage!(stage::_Stage, sim::Simulation)

    for (k, v) in stage.model.canonical.parameters
        parameter_update!(k, v, stage.key, sim)
    end

    return

end
