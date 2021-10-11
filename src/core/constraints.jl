struct AbsoluteValueConstraint <: ConstraintType end
struct ActiveConstraint <: ConstraintType end
struct ActiveRangeConstraint <: ConstraintType end
struct ActiveRangeICConstraint <: ConstraintType end
struct AreaDispatchBalanceConstraint <: ConstraintType end
struct AreaParticipationAssignmentConstraint <: ConstraintType end
struct BalanceAuxConstraint <: ConstraintType end
struct CommitmentConstraint <: ConstraintType end
struct CopperPlateBalanceConstraint <: ConstraintType end
struct DeltaActivePowerDownVariableLimitsConstraint <: ConstraintType end
struct DeltaActivePowerUpVariableLimitsConstraint <: ConstraintType end
struct DurationConstraint <: ConstraintType end
struct EnergyBalanceConstraint <: ConstraintType end
struct EnergyBudgetConstraint <: ConstraintType end
struct EnergyCapacityConstraint <: ConstraintType end
struct EnergyCapacityDownConstraint <: ConstraintType end
struct EnergyCapacityUpConstraint <: ConstraintType end
struct EnergyLimitConstraint <: ConstraintType end
struct EnergyTargetConstraint <: ConstraintType end
struct EnergyShortageVariableLimitsConstraint <: ConstraintType end
struct EqualityConstraint <: ConstraintType end
struct FeedforwardBinConstraint <: ConstraintType end
struct FeedforwardIntegralLimitConstraint <: ConstraintType end
struct FeedforwardUpperBoundConstraint <: ConstraintType end
struct FeedforwardLowerBoundConstraint <: ConstraintType end
struct FeedforwardEnergyTargetConstraint <: ConstraintType end
struct FlowActivePowerConstraint <: ConstraintType end
struct FlowActivePowerFromToConstraint <: ConstraintType end
struct FlowActivePowerToFromConstraint <: ConstraintType end
struct FlowLimitConstraint <: ConstraintType end
struct FlowLimitFromToConstraint <: ConstraintType end
struct FlowLimitToFromConstraint <: ConstraintType end
struct FlowRateConstraint <: ConstraintType end
struct FlowRateConstraintFromTo <: ConstraintType end
struct FlowRateConstraintToFrom <: ConstraintType end
struct FlowReactivePowerConstraint <: ConstraintType end
struct FlowReactivePowerFromToConstraint <: ConstraintType end
struct FlowReactivePowerToFromConstraint <: ConstraintType end
struct FrequencyResponseConstraint <: ConstraintType end
struct InflowRangeConstraint <: ConstraintType end
struct InputPowerRangeConstraint <: ConstraintType end
struct MustRunConstraint <: ConstraintType end
struct NetworkFlowConstraint <: ConstraintType end
struct NodalBalanceActiveConstraint <: ConstraintType end
struct NodalBalanceReactiveConstraint <: ConstraintType end
struct OutputPowerRangeConstraint <: ConstraintType end
struct ParticipationAssignmentConstraint <: ConstraintType end
struct RampConstraint <: ConstraintType end
struct RampLimitConstraint <: ConstraintType end
struct RangeLimitConstraint <: ConstraintType end
struct RateLimitConstraint <: ConstraintType end
struct RateLimitConstraintFromTo <: ConstraintType end
struct RateLimitConstraintToFrom <: ConstraintType end
struct ReactiveConstraint <: ConstraintType end
struct ReactiveRangeConstraint <: ConstraintType end
struct RegulationLimitsDownConstraint <: ConstraintType end
struct RegulationLimitsUpConstraint <: ConstraintType end
struct RequirementConstraint <: ConstraintType end
struct ReserveEnergyConstraint <: ConstraintType end
struct ReservePowerConstraint <: ConstraintType end
struct SACEPidAreaConstraint <: ConstraintType end
struct StartTypeConstraint <: ConstraintType end
struct StartupInitialConditionConstraint <: ConstraintType end
struct StartupTimeLimitTemperatureConstraint <: ConstraintType end

abstract type PowerVariableLimitsConstraint <: ConstraintType end
struct InputActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct OutputActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct ActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct ReactivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct ActivePowerVariableTimeSeriesLimitsConstraint <: PowerVariableLimitsConstraint end

struct ConstraintKey{T <: ConstraintType, U <: Union{PSY.Component, PSY.System}} <:
       OptimizationContainerKey
    meta::String
end

function ConstraintKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    check_meta_chars(meta)
    return ConstraintKey{T, U}(meta)
end

get_entry_type(
    ::ConstraintKey{T, U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}} = T
get_component_type(
    ::ConstraintKey{T, U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}} = U

function encode_key(key::ConstraintKey)
    return encode_symbol(get_component_type(key), get_entry_type(key), key.meta)
end

Base.convert(::Type{ConstraintKey}, name::Symbol) = ConstraintKey(decode_symbol(name)...)
