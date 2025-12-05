abstract type SystemBalanceExpressions <: ExpressionType end
abstract type RangeConstraintLBExpressions <: ExpressionType end
abstract type RangeConstraintUBExpressions <: ExpressionType end
abstract type CostExpressions <: ExpressionType end
abstract type PostContingencyExpressions <: ExpressionType end

abstract type PostContingencySystemBalanceExpressions <: SystemBalanceExpressions end

struct ActivePowerBalance <: SystemBalanceExpressions end
struct PostContingencyActivePowerBalance <: PostContingencySystemBalanceExpressions end
struct ReactivePowerBalance <: SystemBalanceExpressions end
struct EmergencyUp <: ExpressionType end
struct EmergencyDown <: ExpressionType end
struct DeltaActivePowerUpExpression <: ExpressionType end
struct DeltaActivePowerDownExpression <: ExpressionType end
struct AdditionalDeltaActivePowerUpExpression <: ExpressionType end
struct AdditionalDeltaActivePowerDownExpression <: ExpressionType end
struct RawACE <: ExpressionType end
struct ProductionCostExpression <: CostExpressions end
struct FuelConsumptionExpression <: ExpressionType end
struct ActivePowerRangeExpressionLB <: RangeConstraintLBExpressions end
struct ActivePowerRangeExpressionUB <: RangeConstraintUBExpressions end
struct ComponentReserveUpBalanceExpression <: ExpressionType end
struct ComponentReserveDownBalanceExpression <: ExpressionType end
struct InterfaceTotalFlow <: ExpressionType end
struct PTDFBranchFlow <: ExpressionType end
struct PostContingencyBranchFlow <: PostContingencyExpressions end
struct PostContingencyActivePowerGeneration <: PostContingencyExpressions end
struct PostContingencyNodalActivePowerDeployment <: PostContingencyExpressions end
struct NetActivePower <: ExpressionType end
"""
Struct for DC current balance in multi-terminal DC networks
"""
struct DCCurrentBalance <: ExpressionType end

should_write_resulting_value(::Type{<:CostExpressions}) = true
should_write_resulting_value(::Type{FuelConsumptionExpression}) = true
should_write_resulting_value(::Type{InterfaceTotalFlow}) = true
should_write_resulting_value(::Type{RawACE}) = true
should_write_resulting_value(::Type{ActivePowerBalance}) = true
should_write_resulting_value(::Type{ReactivePowerBalance}) = true
should_write_resulting_value(::Type{DCCurrentBalance}) = true
should_write_resulting_value(::Type{AdditionalDeltaActivePowerUpExpression}) = true
should_write_resulting_value(::Type{AdditionalDeltaActivePowerDownExpression}) = true
should_write_resulting_value(::Type{DeltaActivePowerUpExpression}) = true
should_write_resulting_value(::Type{DeltaActivePowerDownExpression}) = true
should_write_resulting_value(::Type{PTDFBranchFlow}) = true
#should_write_resulting_value(::Type{PostContingencyBranchFlow}) = true
#should_write_resulting_value(::Type{PostContingencyActivePowerGeneration}) = true

convert_result_to_natural_units(::Type{InterfaceTotalFlow}) = true
convert_result_to_natural_units(::Type{PostContingencyBranchFlow}) = true
convert_result_to_natural_units(::Type{PostContingencyActivePowerGeneration}) = true
convert_result_to_natural_units(::Type{DeltaActivePowerUpExpression}) = true
convert_result_to_natural_units(::Type{DeltaActivePowerDownExpression}) = true
convert_result_to_natural_units(::Type{AdditionalDeltaActivePowerUpExpression}) = true
convert_result_to_natural_units(::Type{AdditionalDeltaActivePowerDownExpression}) = true
convert_result_to_natural_units(::Type{PTDFBranchFlow}) = true
