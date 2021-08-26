function _get_time_series(
    container::OptimizationContainer,
    component::PSY.Component,
    parameter_attributes::TimeSeriesAttributes{T},
) where {T <: PSY.TimeSeriesData}
    initial_time = get_initial_time(container)
    @debug initial_time
    time_steps = get_time_steps(container)
    forecast = PSY.get_time_series(
        T,
        component,
        get_name(parameter_attributes);
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

function get_time_series(
    container::OptimizationContainer,
    component::T,
    parameter::TimeSeriesParameter,
    name::String,
) where {T <: PSY.Component}
    parameter_container = get_parameter(container, parameter, T, name)
    return _get_time_series(container, component, parameter_container.attributes)
end

# This is just for temporary compatibility with current code. Needs to be eliminated once the time series
# refactor is done.
function get_time_series(
    container::OptimizationContainer,
    component::PSY.Component,
    forecast_name::String,
)
    return _get_time_series(
        container,
        component,
        TimeSeriesAttributes{PSY.Deterministic}(forecast_name),
    )
end
