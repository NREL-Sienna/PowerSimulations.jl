#=
forecasts = PSY.get_forecasts(PSY.Deterministic{PSY.RenewableDispatch}, sim.stages[1].model.sys, sim.ref.date_ref[1])

for forecast in forecasts
    device = PSY.get_forecast_component_name(forecast)
    for (ix,time_step) in enumerate(sim.stages[1].model.canonical.parameters[:P_RenewableDispatch][device,:])
        @show JuMP.value(time_step)
        value = PSY.get_forecast_value(forecast, ix)
        fix(time_step, value)
    end
end
=#