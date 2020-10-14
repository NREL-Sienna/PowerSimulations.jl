function get_time_series(
    psi_container::PSIContainer,
    component::PSY.Component,
    forecast_label::String,
)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    use_forecast_data = model_uses_forecasts(psi_container)
    time_steps = model_time_steps(psi_container)
    if use_forecast_data
         forecast = PSY.get_time_series(
            PSY.Deterministic,
            component,
            forecast_label;
            start_time = initial_time,
            count = 1,
        )
        ts_vector = IS.get_time_series_values(component,
        forecast,
        initial_time;
        len = length(time_steps),
        ignore_scaling_factors = true)
        return ts_vector
    else
        return ones(time_steps[end])
    end
end
