"""
Cache for all model results
"""
mutable struct OptimizationOutputCache
    data::Dict{OutputCacheKey, ModelOutputCache}
    max_size::Int
    min_flush_size::Int
end

function OptimizationOutputCache()
    return OptimizationOutputCache(Dict{OutputCacheKey, ModelOutputCache}(), 0, 0)
end

# PERF: incremental improvement if we manually keep track of the current size.
# Could be prone to bugs if we miss a change.
# The number of containers is not expected to be more than 100.

#decrement_size!(cache::OptimizationOutputCache, size) = cache.size -= size
#increment_size!(cache::OptimizationOutputCache, size) = cache.size += size

get_max_size!(cache::OptimizationOutputCache) = cache.max_size
get_min_flush_size(cache::OptimizationOutputCache) = cache.min_flush_size
get_param_cache(cache::OptimizationOutputCache, key) = cache.data[key]
get_size(cache::OptimizationOutputCache) =
    reduce(+, (get_size(x) for x in values(cache.data)))
is_full(cache::OptimizationOutputCache, cur_size) = cur_size >= cache.max_size
set_max_size!(cache::OptimizationOutputCache, x) = cache.max_size = x
set_min_flush_size!(cache::OptimizationOutputCache, x) = cache.min_flush_size = x

function add_param_cache!(cache::OptimizationOutputCache, key, flush_rule)
    cache.data[key] = ModelOutputCache(key, flush_rule)
    #@debug "Added cache container for" key flush_rule
end

"""
Return true if the cache has data that has not been flushed to storage.
"""
function has_dirty(cache::OptimizationOutputCache)
    for param_cache in values(cache.data)
        if has_dirty(param_cache)
            return true
        end
    end

    return false
end

"""
Return true if the data for `timestamp` is stored in cache.
"""
function is_cached(cache::OptimizationOutputCache, type, name, model, timestamp)
    return is_cached(cache, make_cache_key(model, type, name), timestamp)
end

is_cached(cache::OptimizationOutputCache, key, timestamp) =
    has_timestamp(cache.data[key], timestamp)

"""
Log the cache hit percentages for all caches.
"""
function log_cache_hit_percentages(cache::OptimizationOutputCache)
    for key in sort!(collect(keys(cache.data)))
        param_cache = cache.data[key]
        cache_hit_pecentage = get_cache_hit_percentage(param_cache)
        @debug "Cache stats" key cache_hit_pecentage
    end
end

"""
Read the result from cache. Callers must first call [`is_cached`](@ref) to check if the
timestamp is present.
"""
function read_result(cache::OptimizationOutputCache, model, type, name, timestamp)
    return read_result(cache, make_cache_key(model, type, name), timestamp)
end

read_result(cache::OptimizationOutputCache, key, timestamp) =
    cache.data[key].data[timestamp]
