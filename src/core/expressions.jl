abstract type SystemBalanceExpressions <: ExpressionType end
abstract type RangeConstraintLBExpressions <: ExpressionType end
abstract type RangeConstraintUBExpressions <: ExpressionType end
abstract type CostExpressions <: ExpressionType end
abstract type PostContingencyExpressions <: ExpressionType end

struct ActivePowerBalance <: SystemBalanceExpressions end
struct ReactivePowerBalance <: SystemBalanceExpressions end
struct EmergencyUp <: ExpressionType end
struct EmergencyDown <: ExpressionType end
struct RawACE <: ExpressionType end
struct ProductionCostExpression <: CostExpressions end
struct FuelConsumptionExpression <: ExpressionType end
struct ActivePowerRangeExpressionLB <: RangeConstraintLBExpressions end
struct ActivePowerRangeExpressionUB <: RangeConstraintUBExpressions end
struct ComponentReserveUpBalanceExpression <: ExpressionType end
struct ComponentReserveDownBalanceExpression <: ExpressionType end
struct InterfaceTotalFlow <: ExpressionType end
struct PTDFBranchFlow <: ExpressionType end
struct PTDFPostContingencyBranchFlow <: PostContingencyExpressions end
struct PostContingencyActivePowerGeneration <: PostContingencyExpressions end

should_write_resulting_value(::Type{<:CostExpressions}) = true
should_write_resulting_value(::Type{FuelConsumptionExpression}) = true
should_write_resulting_value(::Type{InterfaceTotalFlow}) = true
should_write_resulting_value(::Type{RawACE}) = true
should_write_resulting_value(::Type{ActivePowerBalance}) = true
should_write_resulting_value(::Type{ReactivePowerBalance}) = true
#should_write_resulting_value(::Type{PTDFPostContingencyBranchFlow}) = true
#should_write_resulting_value(::Type{PostContingencyActivePowerGeneration}) = true

convert_result_to_natural_units(::Type{InterfaceTotalFlow}) = true
#convert_result_to_natural_units(::Type{PTDFPostContingencyBranchFlow}) = true
#convert_result_to_natural_units(::Type{PostContingencyActivePowerGeneration}) = true
