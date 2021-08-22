function get_time_series(
    container::OptimizationContainer,
    component::PSY.Component,
    forecast_name::String,
)
    initial_time = get_initial_time(container)
    @debug initial_time
    time_steps = get_time_steps(container)
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
end
