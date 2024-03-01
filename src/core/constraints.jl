struct AbsoluteValueConstraint <: IS.ConstraintType end
struct ActiveRangeICConstraint <: IS.ConstraintType end
struct AreaDispatchBalanceConstraint <: IS.ConstraintType end
struct AreaParticipationAssignmentConstraint <: IS.ConstraintType end
struct BalanceAuxConstraint <: IS.ConstraintType end
struct CommitmentConstraint <: IS.ConstraintType end
struct CopperPlateBalanceConstraint <: IS.ConstraintType end
struct DurationConstraint <: IS.ConstraintType end
struct EnergyBalanceConstraint <: IS.ConstraintType end
struct EqualityConstraint <: IS.ConstraintType end
struct FeedforwardSemiContinousConstraint <: IS.ConstraintType end
struct FeedforwardIntegralLimitConstraint <: IS.ConstraintType end
struct FeedforwardUpperBoundConstraint <: IS.ConstraintType end
struct FeedforwardLowerBoundConstraint <: IS.ConstraintType end
struct FeedforwardEnergyTargetConstraint <: IS.ConstraintType end
struct FlowActivePowerConstraint <: IS.ConstraintType end #not being used
struct FlowActivePowerFromToConstraint <: IS.ConstraintType end #not being used
struct FlowActivePowerToFromConstraint <: IS.ConstraintType end #not being used
struct FlowLimitConstraint <: IS.ConstraintType end #not being used
struct FlowLimitFromToConstraint <: IS.ConstraintType end
struct FlowLimitToFromConstraint <: IS.ConstraintType end
struct FlowRateConstraint <: IS.ConstraintType end
struct FlowRateConstraintFromTo <: IS.ConstraintType end
struct FlowRateConstraintToFrom <: IS.ConstraintType end
struct FlowReactivePowerConstraint <: IS.ConstraintType end #not being used
struct FlowReactivePowerFromToConstraint <: IS.ConstraintType end #not being used
struct FlowReactivePowerToFromConstraint <: IS.ConstraintType end #not being used
struct HVDCPowerBalance <: IS.ConstraintType end
struct FrequencyResponseConstraint <: IS.ConstraintType end
struct NetworkFlowConstraint <: IS.ConstraintType end
struct NodalBalanceActiveConstraint <: IS.ConstraintType end
struct NodalBalanceReactiveConstraint <: IS.ConstraintType end
struct ParticipationAssignmentConstraint <: IS.ConstraintType end
struct ParticipationFractionConstraint <: IS.ConstraintType end
struct PieceWiseLinearCostConstraint <: IS.ConstraintType end
struct RampConstraint <: IS.ConstraintType end
struct RampLimitConstraint <: IS.ConstraintType end
struct RangeLimitConstraint <: IS.ConstraintType end
struct RateLimitConstraint <: IS.ConstraintType end
struct RateLimitConstraintFromTo <: IS.ConstraintType end
struct RateLimitConstraintToFrom <: IS.ConstraintType end
struct RegulationLimitsConstraint <: IS.ConstraintType end
struct RequirementConstraint <: IS.ConstraintType end
struct ReserveEnergyCoverageConstraint <: IS.ConstraintType end
struct ReservePowerConstraint <: IS.ConstraintType end
struct SACEPIDAreaConstraint <: IS.ConstraintType end
struct StartTypeConstraint <: IS.ConstraintType end
struct StartupInitialConditionConstraint <: IS.ConstraintType end
struct StartupTimeLimitTemperatureConstraint <: IS.ConstraintType end
struct PhaseAngleControlLimit <: IS.ConstraintType end
struct HVDCLossesAbsoluteValue <: IS.ConstraintType end
struct HVDCDirection <: IS.ConstraintType end
struct InterfaceFlowLimit <: IS.ConstraintType end

abstract type PowerVariableLimitsConstraint <: IS.ConstraintType end
struct InputActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct OutputActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct ActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct ReactivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct ActivePowerVariableTimeSeriesLimitsConstraint <: PowerVariableLimitsConstraint end

abstract type EventConstraint <: IS.ConstraintType end
struct OutageConstraint <: EventConstraint end

# These apply to the processing of constraint duals
should_write_resulting_value(::Type{<:IS.ConstraintType}) = true
convert_result_to_natural_units(::Type{<:IS.ConstraintType}) = false
