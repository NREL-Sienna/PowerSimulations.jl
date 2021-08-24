
function get_time_series_values!(
    time_series_type::Type{<:IS.TimeSeriesData},
    model::EmulationModel,
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
            ignore_scaling_factors = true,
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
            ignore_scaling_factors = true,
        )
        cache[key] = ts_cache
    end

    ts = IS.get_time_series_array!(ts_cache, initial_time)
    return TimeSeries.values(ts)
end

function make_time_series_cache(
    time_series_type::Type{T},
    component,
    name,
    initial_time,
    horizon;
    ignore_scaling_factors = true,
) where {T <: IS.TimeSeriesData}
    key = TimeSeriesCacheKey(IS.get_uuid(component), T, name)
    if T <: IS.SingleTimeSeries
        cache = IS.StaticTimeSeriesCache(
            PSY.SingleTimeSeries,
            component,
            name,
            start_time = initial_time,
            ignore_scaling_factors = ignore_scaling_factors,
        )
    elseif T <: IS.Deterministic
        cache = IS.ForecastCache(
            IS.AbstractDeterministic,
            component,
            name,
            start_time = initial_time,
            horizon = horizon,
            ignore_scaling_factors = ignore_scaling_factors,
        )
    elseif T <: IS.Probabilistic
        cache = IS.ForecastCache(
            IS.Probabilistic,
            component,
            name,
            start_time = initial_time,
            horizon = horizon,
            ignore_scaling_factors = ignore_scaling_factors,
        )
    else
        error("not supported yet: $T")
    end

    @debug "Made time series cache for $(summary(component))" name initial_time
    return cache
end
