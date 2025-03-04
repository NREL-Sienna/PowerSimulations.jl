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

For more information check [RenewableGen Formulations](@ref PowerSystems.RenewableGen-Formulations).

The specified constraint is formulated as:

```math
q_t^\\text{re} = \\text{pf} \\cdot p_t^\\text{re}, \\quad \\forall t \\in \\{1,\\dots, T\\}
```
"""
struct EqualityConstraint <: ConstraintType end
"""
Struct to create the constraint for semicontinuous feedforward limits.

For more information check [Feedforward Formulations](@ref ff_formulations).

The specified constraint is formulated as:

```math
\\begin{align*}
&  \\text{ActivePowerRangeExpressionUB}_t := p_t^\\text{th} - \\text{on}_t^\\text{th}P^\\text{th,max} \\le 0, \\quad  \\forall t\\in \\{1, \\dots, T\\}  \\\\
&  \\text{ActivePowerRangeExpressionLB}_t := p_t^\\text{th} - \\text{on}_t^\\text{th}P^\\text{th,min} \\ge 0, \\quad  \\forall t\\in \\{1, \\dots, T\\}
\\end{align*}
```
"""
struct FeedforwardSemiContinuousConstraint <: ConstraintType end
struct FeedforwardIntegralLimitConstraint <: ConstraintType end
"""
Struct to create the constraint for upper bound feedforward limits.

For more information check [Feedforward Formulations](@ref ff_formulations).

The specified constraint is formulated as:

```math
\\begin{align*}
&  \\text{AffectedVariable}_t - p_t^\\text{ff,ubsl} \\le \\text{SourceVariableParameter}_t, \\quad \\forall t \\in \\{1,\\dots, T\\}
\\end{align*}
```
"""
struct FeedforwardUpperBoundConstraint <: ConstraintType end
"""
Struct to create the constraint for lower bound feedforward limits.

For more information check [Feedforward Formulations](@ref ff_formulations).

The specified constraint is formulated as:

```math
\\begin{align*}
&  \\text{AffectedVariable}_t + p_t^\\text{ff,lbsl} \\ge \\text{SourceVariableParameter}_t, \\quad \\forall t \\in \\{1,\\dots, T\\}
\\end{align*}
```
"""
struct FeedforwardLowerBoundConstraint <: ConstraintType end
struct FeedforwardEnergyTargetConstraint <: ConstraintType end
struct FlowActivePowerConstraint <: ConstraintType end #not being used
struct FlowActivePowerFromToConstraint <: ConstraintType end #not being used
struct FlowActivePowerToFromConstraint <: ConstraintType end #not being used
"""
Struct to create the constraint that set the flow limits through a PhaseShiftingTransformer.

For more information check [Branch Formulations](@ref PowerSystems.Branch-Formulations).

The specified constraint is formulated as:

```math
-R^\\text{max} \\le f_t \\le R^\\text{max}, \\quad \\forall t \\in \\{1,\\dots,T\\}
```
"""
struct FlowLimitConstraint <: ConstraintType end
struct FlowLimitFromToConstraint <: ConstraintType end
struct FlowLimitToFromConstraint <: ConstraintType end
"""
Struct to create the constraint that set the flow limits through an HVDC two-terminal branch.

For more information check [Branch Formulations](@ref PowerSystems.Branch-Formulations).

The specified constraint is formulated as:

```math
R^\\text{min} \\le f_t \\le R^\\text{max}, \\quad \\forall t \\in \\{1,\\dots,T\\}
```
"""
struct FlowRateConstraint <: ConstraintType end
"""
Struct to create the constraint that set the flow from-to limits through an HVDC two-terminal branch.

For more information check [Branch Formulations](@ref PowerSystems.Branch-Formulations).

The specified constraint is formulated as:

```math
R^\\text{from,min} \\le f_t^\\text{from-to}  \\le R^\\text{from,max}, \\forall t \\in \\{1,\\dots, T\\}
```
"""
struct FlowRateConstraintFromTo <: ConstraintType end
"""
Struct to create the constraint that set the flow to-from limits through an HVDC two-terminal branch.

For more information check [Branch Formulations](@ref PowerSystems.Branch-Formulations).

The specified constraint is formulated as:

```math
R^\\text{to,min} \\le f_t^\\text{to-from}  \\le R^\\text{to,max},\\quad \\forall t \\in \\{1,\\dots, T\\}
```
"""
struct FlowRateConstraintToFrom <: ConstraintType end
struct FlowReactivePowerConstraint <: ConstraintType end #not being used
struct FlowReactivePowerFromToConstraint <: ConstraintType end #not being used
struct FlowReactivePowerToFromConstraint <: ConstraintType end #not being used
"""
Struct to create the constraints that set the power balance across a lossy HVDC two-terminal line.

For more information check [Branch Formulations](@ref PowerSystems.Branch-Formulations).

The specified constraints are formulated as:

```math
\\begin{align*}
& f_t^\\text{to-from} - f_t^\\text{from-to} \\le L_1 \\cdot f_t^\\text{to-from} - L_0,\\quad \\forall t \\in \\{1,\\dots, T\\} \\\\
& f_t^\\text{from-to} - f_t^\\text{to-from} \\ge L_1 \\cdot f_t^\\text{from-to} + L_0,\\quad \\forall t \\in \\{1,\\dots, T\\} \\\\
& f_t^\\text{from-to} - f_t^\\text{to-from} \\ge - M^\\text{big} (1 - u^\\text{dir}_t),\\quad \\forall t \\in \\{1,\\dots, T\\} \\\\
& f_t^\\text{to-from} - f_t^\\text{from-to} \\ge - M^\\text{big} u^\\text{dir}_t,\\quad \\forall t \\in \\{1,\\dots, T\\} \\\\
\\end{align*}
```
"""
struct HVDCPowerBalance <: ConstraintType end
struct FrequencyResponseConstraint <: ConstraintType end
"""
Struct to create the constraint the AC branch flows depending on the network model.
For more information check [Branch Formulations](@ref PowerSystems.Branch-Formulations).

The specified constraint depends on the network model chosen. The most common application is the StaticBranch in a PTDF Network Model:

```math
f_t = \\sum_{i=1}^N \\text{PTDF}_{i,b} \\cdot \\text{Bal}_{i,t}, \\quad \\forall t \\in \\{1,\\dots, T\\}
```
"""
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
r_{d,t} \\le \\text{Req} \\cdot \\text{PF} ,\\quad \\forall d\\in \\mathcal{D}_s, \\forall t\\in \\{1,\\dots, T\\} \\quad \\text{(for a ConstantReserve)} \\\\
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
Struct to create the PieceWiseLinearBlockOfferConstraint associated with a specified variable.

See [Piecewise linear cost functions](@ref pwl_cost) for more information.
"""
struct PieceWiseLinearBlockOfferConstraint <: ConstraintType end

"""
Struct to create the PieceWiseLinearUpperBoundConstraint associated with a specified variable.

See [Piecewise linear cost functions](@ref pwl_cost) for more information.
"""
struct PieceWiseLinearUpperBoundConstraint <: ConstraintType end

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
"""
Struct to create the constraint that set the AC flow limits through branches.

For more information check [Branch Formulations](@ref PowerSystems.Branch-Formulations).

The specified constraint is formulated as:

```math
\\begin{align*}
&  f_t - f_t^\\text{sl,up} \\le R^\\text{max},\\quad \\forall t \\in \\{1,\\dots, T\\} \\\\
&  f_t + f_t^\\text{sl,lo} \\ge -R^\\text{max},\\quad \\forall t \\in \\{1,\\dots, T\\}
\\end{align*}
```
"""
struct RateLimitConstraint <: ConstraintType end
struct RateLimitConstraintFromTo <: ConstraintType end
struct RateLimitConstraintToFrom <: ConstraintType end
struct RegulationLimitsConstraint <: ConstraintType end
"""
Struct to create the constraint for satisfying active power reserve requirements.
For more information check [Service Formulations](@ref service_formulations).

The constraint is as follows:

```math
\\sum_{d\\in\\mathcal{D}_s} r_{d,t} + r_t^\\text{sl} \\ge \\text{Req},\\quad \\forall t\\in \\{1,\\dots, T\\} \\quad \\text{(for a ConstantReserve)} \\\\
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
"""
Struct to create the constraint that set the angle limits through a PhaseShiftingTransformer.

For more information check [Branch Formulations](@ref PowerSystems.Branch-Formulations).

The specified constraint is formulated as:

```math
\\Theta^\\text{min} \\le \\theta^\\text{shift}_t \\le \\Theta^\\text{max}, \\quad \\forall t \\in \\{1,\\dots,T\\}
```
"""
struct PhaseAngleControlLimit <: ConstraintType end
struct InterfaceFlowLimit <: ConstraintType end
struct HVDCFlowCalculationConstraint <: ConstraintType end

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

"""
Struct to create a constraint that approximates a binary as a function with quadratic polynomial

```math
x^2 - x == 0.0
````
"""
struct ContinousIntegerApproximation <: ConstraintType end

"""
Struct to create a constraint for the convext combination of breakpoints to represent a PWL approximation

```math
\\sum^K_{k = 1} x^k \\delta_k == 1.0
````
"""
struct ConvexCombinationApproximation <: ConstraintType end

"""
Struct to create the unitary constraint in convex combinations

```math
\\sum^K_{k = 1} \\delta_k == 1.0
````
"""
struct ConvexCombinationUnitary <: ConstraintType end

"""
Struct to create the tangent constraint in PieceWiseLinear Approximations
"""
struct PieceWiseLinearApproximationTangent <: ConstraintType end

"""
Struct to create the secant constraint in PieceWiseLinear Approximations
"""
struct PieceWiseLinearApproximationSecant <: ConstraintType end

struct LineFlowBoundConstraint <: ConstraintType end

abstract type EventConstraint <: ConstraintType end
struct OutageConstraint <: EventConstraint end
