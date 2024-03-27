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

struct AbsoluteValueConstraint <: ConstraintType end
struct ActiveRangeICConstraint <: ConstraintType end
struct AreaDispatchBalanceConstraint <: ConstraintType end
struct AreaParticipationAssignmentConstraint <: ConstraintType end
struct BalanceAuxConstraint <: ConstraintType end
struct CommitmentConstraint <: ConstraintType end
struct CopperPlateBalanceConstraint <: ConstraintType end
struct DurationConstraint <: ConstraintType end
struct EnergyBalanceConstraint <: ConstraintType end
struct EqualityConstraint <: ConstraintType end
struct FeedforwardSemiContinousConstraint <: ConstraintType end
struct FeedforwardIntegralLimitConstraint <: ConstraintType end
struct FeedforwardUpperBoundConstraint <: ConstraintType end
struct FeedforwardLowerBoundConstraint <: ConstraintType end
struct FeedforwardEnergyTargetConstraint <: ConstraintType end
struct FlowActivePowerConstraint <: ConstraintType end #not being used
struct FlowActivePowerFromToConstraint <: ConstraintType end #not being used
struct FlowActivePowerToFromConstraint <: ConstraintType end #not being used
struct FlowLimitConstraint <: ConstraintType end #not being used
struct FlowLimitFromToConstraint <: ConstraintType end
struct FlowLimitToFromConstraint <: ConstraintType end
struct FlowRateConstraint <: ConstraintType end
struct FlowRateConstraintFromTo <: ConstraintType end
struct FlowRateConstraintToFrom <: ConstraintType end
struct FlowReactivePowerConstraint <: ConstraintType end #not being used
struct FlowReactivePowerFromToConstraint <: ConstraintType end #not being used
struct FlowReactivePowerToFromConstraint <: ConstraintType end #not being used
struct HVDCPowerBalance <: ConstraintType end
struct FrequencyResponseConstraint <: ConstraintType end
struct NetworkFlowConstraint <: ConstraintType end
struct NodalBalanceActiveConstraint <: ConstraintType end
struct NodalBalanceReactiveConstraint <: ConstraintType end
struct ParticipationAssignmentConstraint <: ConstraintType end
struct ParticipationFractionConstraint <: ConstraintType end
struct PieceWiseLinearCostConstraint <: ConstraintType end
struct RampConstraint <: ConstraintType end
struct RampLimitConstraint <: ConstraintType end
struct RangeLimitConstraint <: ConstraintType end
struct RateLimitConstraint <: ConstraintType end
struct RateLimitConstraintFromTo <: ConstraintType end
struct RateLimitConstraintToFrom <: ConstraintType end
struct RegulationLimitsConstraint <: ConstraintType end
struct RequirementConstraint <: ConstraintType end
struct ReserveEnergyCoverageConstraint <: ConstraintType end
struct ReservePowerConstraint <: ConstraintType end
struct SACEPIDAreaConstraint <: ConstraintType end
struct StartTypeConstraint <: ConstraintType end
struct StartupInitialConditionConstraint <: ConstraintType end
struct StartupTimeLimitTemperatureConstraint <: ConstraintType end
struct PhaseAngleControlLimit <: ConstraintType end
struct HVDCLossesAbsoluteValue <: ConstraintType end
struct HVDCDirection <: ConstraintType end
struct InterfaceFlowLimit <: ConstraintType end

abstract type PowerVariableLimitsConstraint <: ConstraintType end
struct InputActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct OutputActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct ActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct ReactivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
struct ActivePowerVariableTimeSeriesLimitsConstraint <: PowerVariableLimitsConstraint end

# These apply to the processing of constraint duals
should_write_resulting_value(::Type{<:ConstraintType}) = true
convert_result_to_natural_units(::Type{<:ConstraintType}) = false
