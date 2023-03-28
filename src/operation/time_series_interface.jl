function make_time_series_cache(
    ::Type{T},
    component,
    name,
    initial_time,
    len::Int;
    ignore_scaling_factors = true,
) where {T <: PSY.StaticTimeSeries}
    return IS.StaticTimeSeriesCache(
        T,
        component,
        name;
        start_time = initial_time,
        ignore_scaling_factors = ignore_scaling_factors,
    )
end

function make_time_series_cache(
    ::Type{T},
    component,
    name,
    initial_time,
    horizon::Int;
    ignore_scaling_factors = true,
) where {T <: PSY.AbstractDeterministic}
    return IS.ForecastCache(
        T,
        component,
        name;
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
        PSY.Probabilistic,
        component,
        name;
        start_time = initial_time,
        horizon = horizon,
        ignore_scaling_factors = ignore_scaling_factors,
    )
end

function get_time_series_values!(
    time_series_type::Type{T},
    model::DecisionModel,
    component,
    name,
    multiplier_id::Int,
    initial_time,
    horizon::Int;
    ignore_scaling_factors = true,
) where {T <: PSY.Forecast}
    if !use_time_series_cache(get_settings(model))
        return IS.get_time_series_values(
            T,
            component,
            name;
            start_time = initial_time,
            len = horizon,
            ignore_scaling_factors = ignore_scaling_factors,
        )
    end

    cache = get_time_series_cache(model)
    key = TimeSeriesCacheKey(IS.get_uuid(component), T, name, multiplier_id)
    if haskey(cache, key)
        ts_cache = cache[key]
    else
        ts_cache = make_time_series_cache(
            time_series_type,
            component,
            name,
            initial_time,
            horizon;
            ignore_scaling_factors = ignore_scaling_factors,
        )
        cache[key] = ts_cache
    end

    ts = IS.get_time_series_array!(ts_cache, initial_time)
    return TimeSeries.values(ts)
end

function get_time_series_values!(
    ::Type{T},
    model::EmulationModel,
    component::U,
    name,
    multiplier_id::Int,
    initial_time,
    len::Int = 1;
    ignore_scaling_factors = true,
) where {T <: PSY.StaticTimeSeries, U <: PSY.Component}
    if !use_time_series_cache(get_settings(model))
        return IS.get_time_series_values(
            T,
            component,
            name;
            start_time = initial_time,
            len = len,
            ignore_scaling_factors = ignore_scaling_factors,
        )
    end

    cache = get_time_series_cache(model)
    key = TimeSeriesCacheKey(IS.get_uuid(component), T, name, multiplier_id)
    if haskey(cache, key)
        ts_cache = cache[key]
    else
        ts_cache = make_time_series_cache(
            T,
            component,
            name,
            initial_time,
            len;
            ignore_scaling_factors = ignore_scaling_factors,
        )
        cache[key] = ts_cache
    end

    ts = IS.get_time_series_array!(ts_cache, initial_time)
    return TimeSeries.values(ts)
end

function get_time_series_uuid(
    ::Type{T},
    component::U,
    name::AbstractString,
) where {T <: PSY.TimeSeriesData, U <: PSY.Component}
    return string(IS.get_time_series_uuid(T, component, name))
end
