```@meta
CurrentModule = PowerSimulations
DocTestSetup  = quote
    using PowerSimulations
end
```

# API Reference

### Table of Contents

1. [Device Models](#device-models)
2. [Decision Models](#decision-models)
3. [Emulation Models](#emulation-models)
4. [Service Models](#service-models)
5. [Simulation Models](#simulation-models)
6. [Variables](#variables)
7. [Constraints](#constraints)
8. [Parameters](#parameters)

# Device Models

List of structures and methods for Device models

```@docs
DeviceModel
```

### Formulations

Refer to the [Formulations Page](@ref formulation_library) for each Abstract Device Formulation.

### Problem Templates

Refer to the [Problem Templates Page](@ref op_problem_template) for available `ProblemTemplate`s.

### Problem Templates

Refer to the [Problem Templates Page](https://nrel-siip.github.io/PowerSimulations.jl/latest/modeler_guide/problem_templates/) for available `ProblemTemplate`s.

```@raw html
&nbsp;
&nbsp;
```

# Service Models

List of structures and methods for Service models

```@docs
ServiceModel
```

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

### Regulation and Services Variables

```@docs
ActivePowerReserveVariable
ServiceRequirementVariable
DeltaActivePowerUpVariable
DeltaActivePowerDownVariable
AdditionalDeltaActivePowerUpVariable
AdditionalDeltaActivePowerDownVariable
AreaMismatchVariable
SteadyStateFrequencyDeviation
SmoothACE
SystemBalanceSlackUp
SystemBalanceSlackDown
ReserveRequirementSlack
```

```@raw html
&nbsp;
&nbsp;
```

# Constraints

### Common Constraints

```@docs
PieceWiseLinearCostConstraint

```

### Network Constraints

```@docs
AreaDispatchBalanceConstraint
AreaParticipationAssignmentConstraint
BalanceAuxConstraint
CopperPlateBalanceConstraint
FrequencyResponseConstraint
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

### Regulation and Services Constraints

```@docs
ParticipationAssignmentConstraint
RegulationLimitsConstraint
RequirementConstraint
ReserveEnergyCoverageConstraint
ReservePowerConstraint
```

### Thermal Unit Constraints

```@docs
ActiveRangeICConstraint
CommitmentConstraint
DurationConstraint
RampConstraint
RampLimitConstraint
StartupInitialConditionConstraint
StartupTimeLimitTemperatureConstraint
```

### Renewable Unit Constraints

```@docs
EqualityConstraint

```

### Branches Constraints

```@docs
AbsoluteValueConstraint
FlowLimitFromToConstraint
FlowLimitToFromConstraint
FlowRateConstraint
FlowRateConstraintFromTo
FlowRateConstraintToFrom
HVDCDirection
HVDCLossesAbsoluteValue
HVDCPowerBalance
NetworkFlowConstraint
RateLimitConstraint
RateLimitConstraintFromTo
RateLimitConstraintToFrom
PhaseAngleControlLimit
```

### Feedforward Constraints

```@docs
FeedforwardSemiContinousConstraint
FeedforwardIntegralLimitConstraint
FeedforwardUpperBoundConstraint
FeedforwardLowerBoundConstraint
FeedforwardEnergyTargetConstraint
```

# Parameters

## Time Series Parameters

```@docs
ActivePowerTimeSeriesParameter
ReactivePowerTimeSeriesParameter
RequirementTimeSeriesParameter
```

## Variable Value Parameters

```@docs
UpperBoundValueParameter
LowerBoundValueParameter
OnStatusParameter
EnergyLimitParameter
FixValueParameter
EnergyTargetParameter
```

### Objective Function Parameters

```@docs
CostFunctionParameter
```
