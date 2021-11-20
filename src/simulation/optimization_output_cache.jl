"""
Cache for all model results
"""
mutable struct OptimizationResultCache
    data::Dict{OptimizationResultCacheKey, OptimzationResultCache}
    max_size::Int
    min_flush_size::Int
end

function OptimizationResultCache()
    return OptimizationResultCache(
        Dict{OptimizationResultCacheKey, OptimzationResultCache}(),
        0,
        0,
    )
end

# PERF: incremental improvement if we manually keep track of the current size.
# Could be prone to bugs if we miss a change.
# The number of containers is not expected to be more than 100.

#decrement_size!(cache::OptimizationResultCache, size) = cache.size -= size
#increment_size!(cache::OptimizationResultCache, size) = cache.size += size

get_max_size!(cache::OptimizationResultCache) = cache.max_size
get_min_flush_size(cache::OptimizationResultCache) = cache.min_flush_size
get_size(cache::OptimizationResultCache) =
    reduce(+, (get_size(x) for x in values(cache.data)))
is_full(cache::OptimizationResultCache, cur_size) = cur_size >= cache.max_size
set_max_size!(cache::OptimizationResultCache, x) = cache.max_size = x
set_min_flush_size!(cache::OptimizationResultCache, x) = cache.min_flush_size = x

function add_output_cache!(cache::OptimizationResultCache, model_name, key, flush_rule)
    cache_key = OptimizationResultCacheKey(model_name, key)
    cache.data[cache_key] = OptimzationResultCache(cache_key, flush_rule)
    #@debug "Added cache container for" key flush_rule
end

"""
Return true if the cache has data that has not been flushed to storage.
"""
function has_dirty(cache::OptimizationResultCache)
    for output_cache in values(cache.data)
        if has_dirty(output_cache)
            return true
        end
    end

    return false
end

get_output_cache(cache::OptimizationResultCache, key::OptimizationResultCacheKey) =
    cache.data[key]

function get_output_cache(
    cache::OptimizationResultCache,
    model_name,
    key::OptimizationContainerKey,
)
    cache_key = OptimizationResultCacheKey(model_name, key)
    return get_output_cache(cache, cache_key)
end

"""
Return true if the data for `timestamp` is stored in cache.
"""
function is_cached(cache::OptimizationResultCache, model_name, key, timestamp)
    cache_key = OptimizationResultCacheKey(model_name, key)
    return is_cached(cache, cache_key, timestamp)
end

is_cached(cache::OptimizationResultCache, key, timestamp) =
    has_timestamp(cache.data[key], timestamp)

"""
Log the cache hit percentages for all caches.
"""
function log_cache_hit_percentages(cache::OptimizationResultCache)
    for key in keys(cache.data)
        output_cache = cache.data[key]
        cache_hit_pecentage = get_cache_hit_percentage(output_cache)
        @debug "Cache stats" key cache_hit_pecentage
    end
end

"""
Read the result from cache. Callers must first call [`is_cached`](@ref) to check if the
timestamp is present.
"""
function read_result(cache::OptimizationResultCache, model_name, key, timestamp)
    cache_key = OptimizationResultCacheKey(model_name, key)
    return read_result(cache, cache_key, timestamp)
end

read_result(cache::OptimizationResultCache, key, timestamp) =
    cache.data[key].data[timestamp]
