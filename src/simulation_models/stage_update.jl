"""Updates the forecast parameter value"""
function parameter_update!(param_reference::RefParam{T},
                           param_array::JuMPParamArray,
                           stage_number::Int64,
                           sim::Simulation) where T <: PSY.Component

    forecasts = PSY.get_component_forecasts(T,
                                            sim.stages[stage_number].model.sys,
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

function _feedforward_update(::Type{Synchronize},
                          param_reference::RefParam{JuMP.VariableRef},
                          to_stage::_Stage,
                          from_stage::_Stage)

    variable = var(from_stage.model.canonical, param_reference.access_ref)
    #Check that the devices match in the feedforward
    @assert variable.axes[1] == param_reference.axes[1]

    for device_name in axes(variable)[1]

        for t in axes(variable)[2]
            val = value(variable[device_name,t])

            for τ in 1:10
                #fix(EDCvAROpModel.canonical_model.parameters[:ON_ThermalStandard][i,t], val)

            end
        end
    end

    return

end

function _feedforward_update(::Type{RecedingHorizon},
                          param_reference::RefParam{JuMP.VariableRef},
                          param_array::JuMPParamArray,
                          to_stage::_Stage,
                          from_stage::_Stage)

    variable = var(from_stage.model.canonical, param_reference.access_ref)
    #Check that the devices match in the feedforward
    @assert variable.axes[1] == param_reference.axes[1]

    for device_name in axes(variable)[1]

        for t in axes(variable)[2]
            val = value(variable[device_name,t])

            for τ in 1:10
                #fix(EDCvAROpModel.canonical_model.parameters[:ON_ThermalStandard][i,t], val)

            end
        end
    end

    return

end

function parameter_update!(param_reference::RefParam{JuMP.VariableRef},
                           param_array::JuMPParamArray,
                           stage_number::Int64,
                           sim::Simulation)

    feedforward_ref = sim.stages[stage_number].feedforward_ref
    current_stage = sim.stages[stage_number]

    for (k, ref) in feedforward_ref
        _feedforward_update!(ref, param_reference, param_array, current_stage, sim.stages[k])
    end

    for i in axes(param_reference)[1]
        val = value(UCOpModel.canonical_model.variables[:ON_ThermalStandard][i])
    for t in axes(EDCvAROpModel.canonical_model.parameters[:ON_ThermalStandard])[2]
        fix(EDCvAROpModel.canonical_model.parameters[:ON_ThermalStandard][i,t], val)
    end
    end

    return

end

function update_stage!(stage::_Stage, sim::Simulation)

    for (k, v) in stage.model.canonical.parameters
        parameter_update!(k, v, stage.key, sim)
    end

    return

end
