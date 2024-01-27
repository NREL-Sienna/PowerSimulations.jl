struct ExpressionKey{T <: ExpressionType, U <: Union{PSY.Component, PSY.System}} <:
       OptimizationContainerKey
    meta::String
end

function ExpressionKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ExpressionType, U <: Union{PSY.Component, PSY.System}}
    if isabstracttype(U)
        error("Type $U can't be abstract")
    end
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
abstract type RangeConstraintLBExpressions <: ExpressionType end
abstract type RangeConstraintUBExpressions <: ExpressionType end
abstract type CostExpressions <: ExpressionType end
struct ActivePowerBalance <: SystemBalanceExpressions end
struct ReactivePowerBalance <: SystemBalanceExpressions end
struct EmergencyUp <: ExpressionType end
struct EmergencyDown <: ExpressionType end
struct RawACE <: ExpressionType end
struct ProductionCostExpression <: CostExpressions end
struct ActivePowerRangeExpressionLB <: RangeConstraintLBExpressions end
struct ActivePowerRangeExpressionUB <: RangeConstraintUBExpressions end
struct ComponentReserveUpBalanceExpression <: ExpressionType end
struct ComponentReserveDownBalanceExpression <: ExpressionType end
struct InterfaceTotalFlow <: ExpressionType end

should_write_resulting_value(::Type{<:ExpressionType}) = false
should_write_resulting_value(::Type{<:CostExpressions}) = true
should_write_resulting_value(::Type{InterfaceTotalFlow}) = true
should_write_resulting_value(::Type{RawACE}) = true

convert_result_to_natural_units(::Type{<:ExpressionType}) = false
convert_result_to_natural_units(::Type{InterfaceTotalFlow}) = true
