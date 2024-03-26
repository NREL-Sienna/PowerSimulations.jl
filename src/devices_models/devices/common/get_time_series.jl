function _get_time_series(
    container::OptimizationContainer,
    component::PSY.Component,
    attributes::TimeSeriesAttributes{T},
) where {T <: PSY.TimeSeriesData}
    return get_time_series_initial_values!(
        container,
        T,
        component,
        get_time_series_name(attributes),
    )
end

function get_time_series(
    container::OptimizationContainer,
    component::T,
    parameter::TimeSeriesParameter,
    meta = IS.Optimization.CONTAINER_KEY_EMPTY_META,
) where {T <: PSY.Component}
    parameter_container = get_parameter(container, parameter, T, meta)
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
        TimeSeriesAttributes(PSY.Deterministic, forecast_name),
    )
end
