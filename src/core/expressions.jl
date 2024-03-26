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
struct ComponentActivePowerRangeExpressionLB <: RangeConstraintLBExpressions end
struct ReserveRangeExpressionLB <: RangeConstraintLBExpressions end
struct ActivePowerRangeExpressionUB <: RangeConstraintUBExpressions end
struct ReserveRangeExpressionUB <: RangeConstraintUBExpressions end
struct ComponentActivePowerRangeExpressionUB <: RangeConstraintUBExpressions end
struct ComponentReserveUpBalanceExpression <: ExpressionType end
struct ComponentReserveDownBalanceExpression <: ExpressionType end
struct InterfaceTotalFlow <: ExpressionType end

should_write_resulting_value(::Type{<:ExpressionType}) = false
should_write_resulting_value(::Type{<:CostExpressions}) = true
should_write_resulting_value(::Type{InterfaceTotalFlow}) = true
should_write_resulting_value(::Type{RawACE}) = true

convert_result_to_natural_units(::Type{<:ExpressionType}) = false
convert_result_to_natural_units(::Type{InterfaceTotalFlow}) = true
