```@meta
CurrentModule = PowerSimulations
DocTestSetup  = quote
    using PowerSimulations
end
```

# API Reference

### Table of Contents

1. [Device Models](#Device-Models)
    - [Formulations](#Formulations)
    - [Problem Templates](#Problem-Templates)
2. [Decision Models](#Decision-Models)
3. [Emulation Models](#Emulation-Models)
4. [Service Models](#Service-Models)
5. [Simulation Models](#Simulation-Models)
6. [Variables](#Variables)
    - [Common Variables](#Common-Variables)
    - [Thermal Unit Variables](#Thermal-Unit-Variables)
    - [Storage Unit Variables](#Storage-Unit-Variables)
    - [Branches and Network Variables](#Branches-and-Network-Variables)
    - [Services Variables](#Services-Variables)
    - [Feedforward Variables](#Feedforward-Variables)
7. [Constraints](#Constraints)
    - [Common Constraints](#Common-Constraints)
    - [Network Constraints](#Network-Constraints)
    - [Power Variable Limit Constraints](#Power-Variable-Limit-Constraints)
    - [Services Constraints](#Services-Constraints)
    - [Thermal Unit Constraints](#Thermal-Unit-Constraints)
    - [Renewable Unit Constraints](#Renewable-Unit-Constraints)
    - [Branches Constraints](#Branches-Constraints)
    - [Feedforward Constraints](#Feedforward-Constraints)
8. [Parameters](#Parameters)
    - [Time Series Parameters](#Time-Series-Parameters)
    - [Variable Value Parameters](#Variable-Value-Parameters)
    - [Objective Function Parameters](#Objective-Function-Parameters)

```@raw html
&nbsp;
&nbsp;
```

# Device Models

List of structures and methods for Device models

```@docs
DeviceModel
```

### Formulations

Refer to the [Formulations Page](@ref formulation_library) for each Abstract Device Formulation.

### Problem Templates

Refer to the [Problem Templates Page](@ref op_problem_template) for available `ProblemTemplate`s.


```@raw html
&nbsp;
&nbsp;
```

---

# Decision Models

```@docs
DecisionModel
DecisionModel(::Type{M} where {M <: DecisionProblem}, ::ProblemTemplate, ::PSY.System, ::Union{Nothing, JuMP.Model})
DecisionModel(::AbstractString, ::MOI.OptimizerWithAttributes)
build!(::DecisionModel)
solve!(::DecisionModel)
```

```@raw html
&nbsp;
&nbsp;
```

---

# Emulation Models

```@docs
EmulationModel
EmulationModel(::Type{M} where {M <: EmulationProblem}, ::ProblemTemplate, ::PSY.System, ::Union{Nothing, JuMP.Model})
EmulationModel(::AbstractString, ::MOI.OptimizerWithAttributes)
build!(::EmulationModel)
run!(::EmulationModel)
```

```@raw html
&nbsp;
&nbsp;
```

---

# Service Models

List of structures and methods for Service models

```@docs
ServiceModel
```

```@raw html
&nbsp;
&nbsp;
```

---

# Simulation Models

Refer to the [Simulations Page](@ref running_a_simulation) to explanations on how to setup a Simulation, with Sequencing and Feedforwards.

```@docs
SimulationModels
SimulationSequence
Simulation
Simulation(::AbstractString, ::Dict)
build!(::Simulation)
execute!(::Simulation)
```

```@raw html
&nbsp;
&nbsp;
```

---

# Variables

For a list of variables for each device refer to its Formulations page.
### Common Variables

```@docs
ActivePowerVariable
ReactivePowerVariable
PieceWiseLinearCostVariable
```

### Thermal Unit Variables

```@docs
OnVariable
StartVariable
StopVariable
TimeDurationOn
TimeDurationOff
HotStartVariable
WarmStartVariable
ColdStartVariable
PowerAboveMinimumVariable
PowerOutput
```

### Storage Unit Variables

```@docs
ReservationVariable
```

### Branches and Network Variables

```@docs
FlowActivePowerVariable
FlowActivePowerSlackUpperBound
FlowActivePowerSlackLowerBound
FlowActivePowerFromToVariable
FlowActivePowerToFromVariable
FlowReactivePowerFromToVariable
FlowReactivePowerToFromVariable
PhaseShifterAngle
HVDCLosses
HVDCFlowDirectionVariable
VoltageMagnitude
VoltageAngle
```

### Services Variables

```@docs
ActivePowerReserveVariable
ServiceRequirementVariable
SystemBalanceSlackUp
SystemBalanceSlackDown
ReserveRequirementSlack
InterfaceFlowSlackUp
InterfaceFlowSlackDown
```

### Feedforward Variables

```@docs
UpperBoundFeedForwardSlack
LowerBoundFeedForwardSlack
```

```@raw html
&nbsp;
&nbsp;
```

---

# Constraints

### Common Constraints

```@docs
PieceWiseLinearCostConstraint

```

### Network Constraints

```@docs
AreaDispatchBalanceConstraint
CopperPlateBalanceConstraint
NodalBalanceActiveConstraint
NodalBalanceReactiveConstraint
```

### Power Variable Limit Constraints

```@docs
ActivePowerVariableLimitsConstraint
ReactivePowerVariableLimitsConstraint
ActivePowerVariableTimeSeriesLimitsConstraint
InputActivePowerVariableLimitsConstraint
OutputActivePowerVariableLimitsConstraint
```

### Services Constraints

```@docs
RequirementConstraint
ParticipationFractionConstraint
ReservePowerConstraint
```

### Thermal Unit Constraints

```@docs
ActiveRangeICConstraint
CommitmentConstraint
DurationConstraint
RampConstraint
StartupInitialConditionConstraint
StartupTimeLimitTemperatureConstraint
```

### Renewable Unit Constraints

```@docs
EqualityConstraint
```

### Branches Constraints

```@docs
FlowLimitConstraint
FlowRateConstraint
FlowRateConstraintFromTo
FlowRateConstraintToFrom
HVDCLossesAbsoluteValue
HVDCPowerBalance
NetworkFlowConstraint
RateLimitConstraint
PhaseAngleControlLimit
```

### Feedforward Constraints

```@docs
FeedforwardSemiContinuousConstraint
FeedforwardUpperBoundConstraint
FeedforwardLowerBoundConstraint
```

```@raw html
&nbsp;
&nbsp;
```

---

# Parameters

### Time Series Parameters

```@docs
ActivePowerTimeSeriesParameter
ReactivePowerTimeSeriesParameter
RequirementTimeSeriesParameter
```

### Variable Value Parameters

```@docs
UpperBoundValueParameter
LowerBoundValueParameter
OnStatusParameter
FixValueParameter
```

### Objective Function Parameters

```@docs
CostFunctionParameter
```
