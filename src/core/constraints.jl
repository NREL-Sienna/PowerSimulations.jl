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
"""
Struct to create the constraint for starting up ThermalMultiStart units.
For more information check [ThermalGen Formulations](@ref ThermalGen-Formulations) for ThermalMultiStartUnitCommitment.

The specified constraint is formulated as:

```math
\\max\\{P^\\text{th,max} - P^\\text{th,shdown}, 0\\} \\cdot w_1^\\text{th} \\le u^\\text{th,init} (P^\\text{th,max} - P^\\text{th,min}) - P^\\text{th,init}
```
"""
struct ActiveRangeICConstraint <: ConstraintType end
"""
Struct to create the constraint to balance power across specified areas.
For more information check [Network Formulations](@ref network_formulations).

The specified constraint is generally formulated as:

```math
\\sum_{c \\in \\text{components}_a} p_t^c = 0, \\quad \\forall a\\in \\{1,\\dots, A\\}, t \\in \\{1, \\dots, T\\}
```
"""
struct AreaDispatchBalanceConstraint <: ConstraintType end
struct AreaParticipationAssignmentConstraint <: ConstraintType end
struct BalanceAuxConstraint <: ConstraintType end
"""
Struct to create the commitment constraint between the on, start, and stop variables.
For more information check [ThermalGen Formulations](@ref ThermalGen-Formulations).

The specified constraints are formulated as:

```math
u_1^\\text{th} = u^\\text{th,init} + v_1^\\text{th} - w_1^\\text{th} \\\\
u_t^\\text{th} = u_{t-1}^\\text{th} + v_t^\\text{th} - w_t^\\text{th}, \\quad \\forall t \\in \\{2,\\dots,T\\} \\\\
v_t^\\text{th} + w_t^\\text{th} \\le 1, \\quad \\forall t \\in \\{1,\\dots,T\\}
```
"""
struct CommitmentConstraint <: ConstraintType end
"""
Struct to create the constraint to balance power in the copperplate model.
For more information check [Network Formulations](@ref network_formulations).

The specified constraint is generally formulated as:

```math
\\sum_{c \\in \\text{components}} p_t^c = 0, \\quad \\forall t \\in \\{1, \\dots, T\\}
```
"""
struct CopperPlateBalanceConstraint <: ConstraintType end
"""
Struct to create the duration constraint for commitment formulations, i.e. min-up and min-down.

For more information check [ThermalGen Formulations](@ref ThermalGen-Formulations).
"""
struct DurationConstraint <: ConstraintType end
struct EnergyBalanceConstraint <: ConstraintType end

"""
Struct to create the constraint that sets the reactive power to the power factor
in the RenewableConstantPowerFactor formulation for renewable units.

For more information check [RenewableGen Formulations](@ref RenewableGen-Formulations).

The specified constraint is formulated as:

```math
q_t^\\text{re} = \\text{pf} \\cdot p_t^\\text{re}, \\quad \\forall t \\in \\{1,\\dots, T\\}
```
"""
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
"""
Struct to create the constraint to balance active power in nodal formulation.
For more information check [Network Formulations](@ref network_formulations).

The specified constraint depends on the network model chosen.
"""
struct NodalBalanceActiveConstraint <: ConstraintType end
"""
Struct to create the constraint to balance reactive power in nodal formulation.
For more information check [Network Formulations](@ref network_formulations).

The specified constraint depends on the network model chosen.
"""
struct NodalBalanceReactiveConstraint <: ConstraintType end
struct ParticipationAssignmentConstraint <: ConstraintType end
"""
Struct to create the constraint to participation assignments limits in the active power reserves.
For more information check [Service Formulations](@ref service_formulations).

The constraint is as follows:

```math
r_{d,t} \\le \\text{Req} \\cdot \\text{PF} ,\\quad \\forall d\\in \\mathcal{D}_s, \\forall t\\in \\{1,\\dots, T\\} \\quad \\text{(for a StaticReserve)} \\\\
r_{d,t} \\le \\text{RequirementTimeSeriesParameter}_{t} \\cdot \\text{PF}\\quad  \\forall d\\in \\mathcal{D}_s, \\forall t\\in \\{1,\\dots, T\\}, \\quad \\text{(for a VariableReserve)}
```
"""
struct ParticipationFractionConstraint <: ConstraintType end
"""
Struct to create the PieceWiseLinearCostConstraint associated with a specified variable.

See [Piecewise linear cost functions](@ref pwl_cost) for more information.
"""
struct PieceWiseLinearCostConstraint <: ConstraintType end
"""
Struct to create the RampConstraint associated with a specified thermal device or reserve service.

For thermal units, see more information in [Thermal Formulations](@ref ThermalGen-Formulations). The constraint is as follows:
```math
-R^\\text{th,dn} \\le p_t^\\text{th} - p_{t-1}^\\text{th} \\le R^\\text{th,up}, \\quad \\forall  t\\in \\{1, \\dots, T\\}
```

For Ramp Reserve, see more information in [Service Formulations](@ref service_formulations). The constraint is as follows:

```math
r_{d,t} \\le R^\\text{th,up} \\cdot \\text{TF}\\quad  \\forall d\\in \\mathcal{D}_s, \\forall t\\in \\{1,\\dots, T\\}, \\quad \\text{(for ReserveUp)} \\\\
r_{d,t} \\le R^\\text{th,dn} \\cdot \\text{TF}\\quad  \\forall d\\in \\mathcal{D}_s, \\forall t\\in \\{1,\\dots, T\\}, \\quad \\text{(for ReserveDown)}
```
"""
struct RampConstraint <: ConstraintType end
struct RampLimitConstraint <: ConstraintType end
struct RangeLimitConstraint <: ConstraintType end
struct RateLimitConstraint <: ConstraintType end
struct RateLimitConstraintFromTo <: ConstraintType end
struct RateLimitConstraintToFrom <: ConstraintType end
struct RegulationLimitsConstraint <: ConstraintType end
"""
Struct to create the constraint for satisfying active power reserve requirements.
For more information check [Service Formulations](@ref service_formulations).

The constraint is as follows:

```math
\\sum_{d\\in\\mathcal{D}_s} r_{d,t} + r_t^\\text{sl} \\ge \\text{Req},\\quad \\forall t\\in \\{1,\\dots, T\\} \\quad \\text{(for a StaticReserve)} \\\\
\\sum_{d\\in\\mathcal{D}_s} r_{d,t} + r_t^\\text{sl} \\ge \\text{RequirementTimeSeriesParameter}_{t},\\quad \\forall t\\in \\{1,\\dots, T\\} \\quad \\text{(for a VariableReserve)}
```
"""
struct RequirementConstraint <: ConstraintType end
struct ReserveEnergyCoverageConstraint <: ConstraintType end
"""
Struct to create the constraint for ensuring that NonSpinning Reserve can be delivered from turn-off thermal units.

For more information check [Service Formulations](@ref service_formulations) for NonSpinningReserve.

The constraint is as follows:

```math
r_{d,t} \\le (1 - u_{d,t}^\\text{th}) \\cdot R^\\text{limit}_d, \\quad \\forall d \\in \\mathcal{D}_s, \\forall t \\in \\{1,\\dots, T\\}
```
"""
struct ReservePowerConstraint <: ConstraintType end
struct SACEPIDAreaConstraint <: ConstraintType end
struct StartTypeConstraint <: ConstraintType end
"""
Struct to create the start-up initial condition constraints for ThermalMultiStart.

For more information check [ThermalGen Formulations](@ref ThermalGen-Formulations) for ThermalMultiStartUnitCommitment.
"""
struct StartupInitialConditionConstraint <: ConstraintType end
"""
Struct to create the start-up time limit constraints for ThermalMultiStart.

For more information check [ThermalGen Formulations](@ref ThermalGen-Formulations) for ThermalMultiStartUnitCommitment.
"""
struct StartupTimeLimitTemperatureConstraint <: ConstraintType end
struct PhaseAngleControlLimit <: ConstraintType end
struct HVDCLossesAbsoluteValue <: ConstraintType end
struct HVDCDirection <: ConstraintType end
struct InterfaceFlowLimit <: ConstraintType end

abstract type PowerVariableLimitsConstraint <: ConstraintType end
"""
Struct to create the constraint to limit active power input expressions.
For more information check [Device Formulations](@ref formulation_intro).

The specified constraint depends on the UpperBound and LowerBound expressions, but
in its most basic formulation is of the form:

```math
P^\\text{min} \\le p_t^\\text{in} \\le P^\\text{max}, \\quad \\forall t \\in \\{1,\\dots,T\\}
```
"""
struct InputActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
"""
Struct to create the constraint to limit active power output expressions.
For more information check [Device Formulations](@ref formulation_intro).

The specified constraint depends on the UpperBound and LowerBound expressions, but
in its most basic formulation is of the form:

```math
P^\\text{min} \\le p_t^\\text{out} \\le P^\\text{max}, \\quad \\forall t \\in \\{1,\\dots,T\\}
```
"""
struct OutputActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
"""
Struct to create the constraint to limit active power expressions.
For more information check [Device Formulations](@ref formulation_intro).

The specified constraint depends on the UpperBound and LowerBound expressions, but
in its most basic formulation is of the form:

```math
P^\\text{min} \\le p_t \\le P^\\text{max}, \\quad \\forall t \\in \\{1,\\dots,T\\}
```
"""
struct ActivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
"""
Struct to create the constraint to limit reactive power expressions.
For more information check [Device Formulations](@ref formulation_intro).

The specified constraint depends on the UpperBound and LowerBound expressions, but
in its most basic formulation is of the form:

```math
Q^\\text{min} \\le q_t \\le Q^\\text{max}, \\quad \\forall t \\in \\{1,\\dots,T\\}
```
"""
struct ReactivePowerVariableLimitsConstraint <: PowerVariableLimitsConstraint end
"""
Struct to create the constraint to limit active power expressions by a time series parameter.
For more information check [Device Formulations](@ref formulation_intro).

The specified constraint depends on the UpperBound expressions, but
in its most basic formulation is of the form:

```math
p_t \\le \\text{ActivePowerTimeSeriesParameter}_t, \\quad \\forall t \\in \\{1,\\dots,T\\}
```
"""
struct ActivePowerVariableTimeSeriesLimitsConstraint <: PowerVariableLimitsConstraint end

# These apply to the processing of constraint duals
should_write_resulting_value(::Type{<:ConstraintType}) = true
convert_result_to_natural_units(::Type{<:ConstraintType}) = false
