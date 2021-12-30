function _get_time_series(
    container::OptimizationContainer,
    component::PSY.Component,
    attributes::TimeSeriesAttributes{T},
) where {T <: PSY.TimeSeriesData}
    initial_time = get_initial_time(container)
    time_steps = get_time_steps(container)
    forecast = PSY.get_time_series(
        T,
        component,
        get_time_series_name(attributes);
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
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: PSY.Component}
    parameter_container = get_parameter(container, parameter, T, meta)
    parameter_container.attributes
    return _get_time_series(container, component, parameter_container.attributes)
end

function get_time_series(
    container::OptimizationContainer,
    component::T,
    parameter::ActivePowerTimeSeriesParameter,
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: PSY.HybridSystem}
    parameter_container = get_parameter(container, parameter, T, meta)
    parameter_container.attributes
    return _get_time_series(
        container,
        PSY.get_renewable_unit(component),
        parameter_container.attributes,
    )
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
        TimeSeriesAttributes(PSY.Deterministic, forecast_name),
    )
end
