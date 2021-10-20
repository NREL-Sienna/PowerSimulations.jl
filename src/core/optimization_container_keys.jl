abstract type OptimizationContainerKey end

const _DELIMITER = "__"

function make_key(::Type{T}, args...) where {T <: OptimizationContainerKey}
    return T(args...)
end

function encode_key(key::OptimizationContainerKey)
    return encode_symbol(get_component_type(key), get_entry_type(key), key.meta)
end

encode_key_as_string(key::OptimizationContainerKey) = string(encode_key(key))
encode_keys_as_strings(container_keys) = [encode_key_as_string(k) for k in container_keys]

function encode_symbol(
    ::Type{T},
    ::Type{U},
    meta::String = CONTAINER_KEY_EMPTY_META,
) where {T <: Union{PSY.Component, PSY.System}, U}
    meta_ = isempty(meta) ? meta : _DELIMITER * meta
    T_ = replace(replace(IS.strip_module_name(T), "{" => _DELIMITER), "}" => "")
    return Symbol("$(IS.strip_module_name(string(U)))$(_DELIMITER)$(T_)" * meta_)
end

function check_meta_chars(meta)
    # Underscores in this field will prevent us from being able to decode keys.
    if occursin(_DELIMITER, meta)
        throw(IS.InvalidValue("'$_DELIMITER' is not allowed in meta"))
    end
end
