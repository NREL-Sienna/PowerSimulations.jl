"""Updates the forecast parameter value"""
function parameter_update!(param_reference::PSI.RefParam{T},
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


function parameter_update!(param_reference::PSI.RefParam{JuMP.VariableRef},
                           param_array::JuMPParamArray,
                           stage_number::Int64,
                           sim::Simulation)

    return

end
