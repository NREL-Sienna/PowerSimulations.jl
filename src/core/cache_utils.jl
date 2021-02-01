const ParamCacheKey = NamedTuple{(:stage, :type, :name), NTuple{3, Symbol}}

make_cache_key(stage, type, name) = (stage = stage, type = type, name = name)

# Priority for keeping data in cache to serve reads. Currently unused.
IS.@scoped_enum(CachePriority, LOW = 1, MEDIUM = 2, HIGH = 3,)

struct CacheFlushRule
    keep_in_cache::Bool
    priority::CachePriority
end

CacheFlushRule() = CacheFlushRule(false, CachePriority.LOW)

"""
Informs the flusher on what data to keep in cache.
"""
struct CacheFlushRules
    data::Dict{ParamCacheKey, CacheFlushRule}
    min_flush_size::Int
    max_size::Int
end

function CacheFlushRules(; max_size = GiB, min_flush_size = MiB)
    return CacheFlushRules(Dict{ParamCacheKey, CacheFlushRule}(), min_flush_size, max_size)
end

function add_rule!(rules::CacheFlushRules, stage, type, name, keep_in_cache, priority)
    key = make_cache_key(stage, type, name)
    rules.data[key] = CacheFlushRule(keep_in_cache, priority)
end

get_rule(x::CacheFlushRules, stage, type, name) =
    get_rule(x, make_cache_key(stage, type, name))
get_rule(x::CacheFlushRules, key) = x.data[key]

mutable struct CacheStats
    hits::Int
    misses::Int
end

CacheStats() = CacheStats(0, 0)

function get_cache_hit_percentage(x::CacheStats)
    total = x.hits + x.misses
    total == 0 && return 0.0

    return x.hits / (x.hits + x.misses) * 100
end
