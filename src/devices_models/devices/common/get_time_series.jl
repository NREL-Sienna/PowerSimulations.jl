function get_time_series(
    optimization_container::OptimizationContainer,
    component::PSY.Component,
    forecast_name::String,
)
    initial_time = get_initial_time(optimization_container)
    @debug initial_time
    use_forecast_data = model_uses_forecasts(optimization_container)
    time_steps = get_time_steps(optimization_container)
    if use_forecast_data
        forecast = PSY.get_time_series(
            PSY.Deterministic,
            component,
            forecast_name;
            start_time = initial_time,
            count = 1,
        )
        ts_vector = IS.get_time_series_values(
            component,
            forecast,
            initial_time;
            len = length(time_steps),
            ignore_scaling_factors = true,
        )
        return ts_vector
    else
        return ones(time_steps[end])
    end
end
