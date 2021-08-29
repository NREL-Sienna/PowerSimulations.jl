struct TimeSeriesCacheKey
    component_uuid::Base.UUID
    time_series_type::Type{<:IS.TimeSeriesData}
    name::String
end

function make_time_series_cache(
    ::Type{PSY.StaticTimeSeries},
    component,
    name,
    initial_time,
    ::Int;
    ignore_scaling_factors = true,
)
    return IS.StaticTimeSeriesCache(
        PSY.SingleTimeSeries,
        component,
        name,
        start_time = initial_time,
        ignore_scaling_factors = ignore_scaling_factors,
    )
end

function make_time_series_cache(
    ::Type{PSY.Deterministic},
    component,
    name,
    initial_time,
    horizon::Int;
    ignore_scaling_factors = true,
)
    return IS.ForecastCache(
        PSY.AbstractDeterministic,
        component,
        name,
        start_time = initial_time,
        horizon = horizon,
        ignore_scaling_factors = ignore_scaling_factors,
    )
end

function make_time_series_cache(
    ::Type{PSY.Probabilistic},
    component,
    name,
    initial_time,
    horizon::Int;
    ignore_scaling_factors = true,
)
    return IS.ForecastCache(
        PSY.AbstractDeterministic,
        component,
        name,
        start_time = initial_time,
        horizon = horizon,
        ignore_scaling_factors = ignore_scaling_factors,
    )
end

function get_time_series_values!(
    time_series_type::Type{<:PSY.Forecast},
    model::DecisionModel,
    component,
    name,
    initial_time,
    horizon;
    ignore_scaling_factors = true,
)
    if !use_time_series_cache(get_settings(model))
        return IS.get_time_series_values(
            time_series_type,
            component,
            name,
            start_time = initial_time,
            len = horizon,
            ignore_scaling_factors = ignore_scaling_factors,
        )
    end

    cache = get_time_series_cache(model)
    key = TimeSeriesCacheKey(IS.get_uuid(component), time_series_type, name)
    if haskey(cache, key)
        ts_cache = cache[key]
    else
        ts_cache = make_time_series_cache(
            time_series_type,
            component,
            name,
            initial_time,
            horizon,
            ignore_scaling_factors = ignore_scaling_factors,
        )
        cache[key] = ts_cache
    end

    ts = IS.get_time_series_array!(ts_cache, initial_time)
    return TimeSeries.values(ts)
end

function get_time_series_values!(
    time_series_type::Type{PSY.StaticTimeSeries},
    model::EmulationModel,
    component,
    name,
    initial_time,
    len::Int = 1;
    ignore_scaling_factors = true,
)
    if !use_time_series_cache(get_settings(model))
        return IS.get_time_series_values(
            time_series_type,
            component,
            name,
            start_time = initial_time,
            len = len,
            ignore_scaling_factors = ignore_scaling_factors,
        )
    end

    cache = get_time_series_cache(model)
    key = TimeSeriesCacheKey(IS.get_uuid(component), time_series_type, name)
    if haskey(cache, key)
        ts_cache = cache[key]
    else
        ts_cache = make_time_series_cache(
            time_series_type,
            component,
            name,
            initial_time,
            len,
            ignore_scaling_factors = ignore_scaling_factors,
        )
        cache[key] = ts_cache
    end

    ts = IS.get_time_series_array!(ts_cache, initial_time)
    return TimeSeries.values(ts)
end
