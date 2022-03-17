"""
Cache for a single parameter/variable/dual.
Stores arrays chronologically by simulation timestamp.
"""
mutable struct OptimzationResultCache
    key::OptimizationResultCacheKey
    "Contains both clean and dirty entries. Any key in data that is earlier than the first
    dirty timestamp must be clean."
    data::OrderedDict{Dates.DateTime, Array}
    "Oldest entry is first"
    dirty_timestamps::Deque{Dates.DateTime}
    stats::CacheStats
    size_per_entry::Int
    flush_rule::CacheFlushRule
end

function OptimzationResultCache(key, flush_rule)
    return OptimzationResultCache(
        key,
        OrderedDict{Dates.DateTime, Array}(),
        Deque{Dates.DateTime}(),
        CacheStats(),
        0,
        flush_rule,
    )
end

Base.length(x::OptimzationResultCache) = length(x.data)
get_cache_hit_percentage(x::OptimzationResultCache) = get_cache_hit_percentage(x.stats)
get_size(x::OptimzationResultCache) = length(x) * x.size_per_entry
has_clean(x::OptimzationResultCache) = !isempty(x.data) && !is_dirty(x, first(keys(x.data)))
has_dirty(x::OptimzationResultCache) = !isempty(x.dirty_timestamps)
should_keep_in_cache(x::OptimzationResultCache) = x.flush_rule.keep_in_cache

function get_dirty_size(cache::OptimzationResultCache)
    return length(cache.dirty_timestamps) * cache.size_per_entry
end

function is_dirty(cache::OptimzationResultCache, timestamp)
    isempty(cache.dirty_timestamps) && return false
    return timestamp >= first(cache.dirty_timestamps)
end

function Base.empty!(cache::OptimzationResultCache)
    @assert isempty(cache.dirty_timestamps) "dirty cache was still present $(cache.key) $(cache.dirty_timestamps)"
    empty!(cache.data)
    cache.size_per_entry = 0
    return
end

"""
Add result to the cache.
"""
function add_result!(cache::OptimzationResultCache, timestamp, array, system_cache_is_full)
    if cache.size_per_entry == 0
        cache.size_per_entry = length(array) * sizeof(first(array))
    end

    @debug "add_result!" cache.key timestamp get_size(cache)
    if haskey(cache.data, timestamp)
        throw(IS.InvalidValue("$timestamp is already stored in $(cache.key)"))
    end

    # Note that we buffer all writes in cache until we reach the flush size.
    # The entries using "should_keep_in_cache" can grow quite large for read caching.
    if system_cache_is_full && should_keep_in_cache(cache)
        if has_clean(cache)
            popfirst!(cache.data)
            @debug "replaced cache entry" LOG_GROUP_SIMULATION_STORE cache.key length(
                cache.data,
            )
        end
    end

    _add_result!(cache, timestamp, array)
    return cache.size_per_entry
end

function _add_result!(cache::OptimzationResultCache, timestamp, data)
    cache.data[timestamp] = data
    push!(cache.dirty_timestamps, timestamp)
    return
end

function discard_results!(cache::OptimzationResultCache, timestamps)
    for timestamp in timestamps
        pop!(cache.data, timestamp)
    end

    @debug "Removed $(first(timestamps)) - $(last(timestamps)) from cache" cache.key
    return
end

"""
Return all dirty data from the cache. Mark the timestamps as clean.
"""
function get_dirty_data_to_flush!(cache::OptimzationResultCache)
    timestamps = [x for x in cache.dirty_timestamps]
    empty!(cache.dirty_timestamps)
    # Uncomment for performance testing of CacheFlush
    #TimerOutputs.@timeit RUN_SIMULATION_TIMER "Concatenate arrays for flush" begin
    arrays = (cache.data[x] for x in timestamps)
    arrays = cat(arrays..., dims=ndims(first(arrays)) + 1)
    #end

    return timestamps, arrays
end

function has_timestamp(cache::OptimzationResultCache, timestamp)
    present = haskey(cache.data, timestamp)
    if present
        cache.stats.hits += 1
    else
        cache.stats.misses += 1
    end

    return present
end
