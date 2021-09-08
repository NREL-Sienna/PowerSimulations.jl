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

abstract type SystemBalanceExpressions <: ExpressionType end
abstract type RangeConstraintExpressions <: ExpressionType end
struct ActivePowerBalance <: SystemBalanceExpressions end
struct ReactivePowerBalance <: SystemBalanceExpressions end
struct EmergencyUp <: ExpressionType end
struct EmergencyDown <: ExpressionType end
struct RawACE <: ExpressionType end
struct ActivePowerRangeExpression <: RangeConstraintExpressions end
struct ActivePowerInRangeExpression <: RangeConstraintExpressions end
struct ActivePowerOutRangeExpression <: RangeConstraintExpressions end
struct ReserveRangeExpression <: RangeConstraintExpressions end
