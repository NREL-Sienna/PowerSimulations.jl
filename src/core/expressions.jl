struct ExpressionKey{T <: ExpressionType, U <: Union{PSY.Component, PSY.System}} <:
       OptimizationContainerKey
    meta::String
end

function ExpressionKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ExpressionType, U <: Union{PSY.Component, PSY.System}}
    check_meta_chars(meta)
    return ExpressionKey{T, U}(meta)
end

get_entry_type(
    ::ExpressionKey{T, U},
) where {T <: ExpressionType, U <: Union{PSY.Component, PSY.System}} = T

get_component_type(
    ::ExpressionKey{T, U},
) where {T <: ExpressionType, U <: Union{PSY.Component, PSY.System}} = U

function encode_key(key::ExpressionKey)
    return encode_symbol(get_component_type(key), get_entry_type(key), key.meta)
end

Base.convert(::Type{ExpressionKey}, name::Symbol) = ExpressionKey(decode_symbol(name)...)

struct ActivePowerBalance <: ExpressionType end
struct ReactivePowerBalance <: ExpressionType end
