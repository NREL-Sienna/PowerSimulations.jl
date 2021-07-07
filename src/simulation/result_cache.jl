"""
Cache for all model results
"""
mutable struct ResultCache
    data::Dict{ParamCacheKey, ParamResultCache}
    max_size::Int
    min_flush_size::Int
end

function ResultCache()
    return ResultCache(Dict{ParamCacheKey, ParamResultCache}(), 0, 0)
end

# PERF: incremental improvement if we manually keep track of the current size.
# Could be prone to bugs if we miss a change.
# The number of containers is not expected to be more than 100.

#decrement_size!(cache::ResultCache, size) = cache.size -= size
#increment_size!(cache::ResultCache, size) = cache.size += size

get_max_size!(cache::ResultCache) = cache.max_size
get_min_flush_size(cache::ResultCache) = cache.min_flush_size
get_param_cache(cache::ResultCache, key) = cache.data[key]
get_size(cache::ResultCache) = reduce(+, (get_size(x) for x in values(cache.data)))
is_full(cache::ResultCache, cur_size) = cur_size >= cache.max_size
set_max_size!(cache::ResultCache, x) = cache.max_size = x
set_min_flush_size!(cache::ResultCache, x) = cache.min_flush_size = x

function add_param_cache!(cache::ResultCache, key, flush_rule)
    cache.data[key] = ParamResultCache(key, flush_rule)
    #@debug "Added cache container for" key flush_rule
end

"""
Return true if the cache has data that has not been flushed to storage.
"""
function has_dirty(cache::ResultCache)
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
function is_cached(cache::ResultCache, type, name, problem, timestamp)
    return is_cached(cache, make_cache_key(problem, type, name), timestamp)
end

is_cached(cache::ResultCache, key, timestamp) = has_timestamp(cache.data[key], timestamp)

"""
Log the cache hit percentages for all caches.
"""
function log_cache_hit_percentages(cache::ResultCache)
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
function read_result(cache::ResultCache, problem, type, name, timestamp)
    return read_result(cache, make_cache_key(problem, type, name), timestamp)
end

read_result(cache::ResultCache, key, timestamp) = cache.data[key].data[timestamp]
