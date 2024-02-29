abstract type SystemBalanceExpressions <: IS.ExpressionType end
abstract type RangeConstraintLBExpressions <: IS.ExpressionType end
abstract type RangeConstraintUBExpressions <: IS.ExpressionType end
abstract type CostExpressions <: IS.ExpressionType end
struct ActivePowerBalance <: SystemBalanceExpressions end
struct ReactivePowerBalance <: SystemBalanceExpressions end
struct EmergencyUp <: IS.ExpressionType end
struct EmergencyDown <: IS.ExpressionType end
struct RawACE <: IS.ExpressionType end
struct ProductionCostExpression <: CostExpressions end
struct ActivePowerRangeExpressionLB <: RangeConstraintLBExpressions end
struct ComponentActivePowerRangeExpressionLB <: RangeConstraintLBExpressions end
struct ReserveRangeExpressionLB <: RangeConstraintLBExpressions end
struct ActivePowerRangeExpressionUB <: RangeConstraintUBExpressions end
struct ReserveRangeExpressionUB <: RangeConstraintUBExpressions end
struct ComponentActivePowerRangeExpressionUB <: RangeConstraintUBExpressions end
struct ComponentReserveUpBalanceExpression <: IS.ExpressionType end
struct ComponentReserveDownBalanceExpression <: IS.ExpressionType end
struct InterfaceTotalFlow <: IS.ExpressionType end

should_write_resulting_value(::Type{<:IS.ExpressionType}) = false
should_write_resulting_value(::Type{<:CostExpressions}) = true
should_write_resulting_value(::Type{InterfaceTotalFlow}) = true
should_write_resulting_value(::Type{RawACE}) = true

convert_result_to_natural_units(::Type{<:IS.ExpressionType}) = false
convert_result_to_natural_units(::Type{InterfaceTotalFlow}) = true
