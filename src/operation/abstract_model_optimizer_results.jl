abstract type AbstractModelOptimizerResults end

# Required methods for subtypes:
# - write_result!
# - read_results
# - write_optimizer_stats!
# - read_optimizer_stats
#
# Each subtype must have a field for each instance of STORE_CONTAINERS.

function Base.empty!(results::AbstractModelOptimizerResults)
    rtype = typeof(results)
    for (name, type) in zip(fieldnames(rtype), fieldtypes(rtype))
        val = getfield(results, name)
        try
            empty!(val)
        catch
            @error "Base.empty! must be customized for type $rtype"
            rethrow()
        end
    end
end

function list_fields(results::AbstractModelOptimizerResults, container_type::Symbol)
    return keys(getfield(results, container_type))
end

function write_result!(results::AbstractModelOptimizerResults, key, index, array, columns)
    field = get_store_container_type(key)
    return write_result!(results, field, key, index, array, columns)
end

function read_results(results::AbstractModelOptimizerResults, key, index = nothing)
    field = get_store_container_type(key)
    return read_results(results, field, key, index)
end

function read_results(
    ::Type{DataFrames.DataFrame},
    results::AbstractModelOptimizerResults,
    container_type::Symbol,
    key,
    index = nothing,
)
    return read_results(results, container_type, key, index)
end
