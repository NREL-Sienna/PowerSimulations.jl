```@meta
CurrentModule = PowerSimulations
DocTestSetup  = quote
    using PowerSimulations
end
```

# API Reference

```@contents
Pages = ["PowerSimulations.md"]
Depth = 3
```

```@raw html
&nbsp;
&nbsp;
```

## Device Models

List of structures and methods for Device models

```@docs
DeviceModel
```

### Formulations

Refer to the [Formulations Page](@ref formulation_library) for each Abstract Device Formulation.

### Problem Templates

```@autodocs
Modules = [PowerSimulations]
Pages   = ["problem_template.jl",
            "operation_problem_templates.jl",
           ]
Order = [:type, :function]
Public = true
Private = false
```

```@raw html
&nbsp;
&nbsp;
```

* * *

## Decision Models

```@autodocs
Modules = [PowerSimulations]
Pages   = ["decision_model.jl",
           ]
Order = [:type, :function]
Public = true
Private = false
```

```@raw html
&nbsp;
&nbsp;
```

* * *

## Emulation Models

```@docs
EmulationModel
EmulationModel(::Type{M} where {M <: EmulationProblem}, ::ProblemTemplate, ::PSY.System, ::Union{Nothing, JuMP.Model})
EmulationModel(::AbstractString, ::MOI.OptimizerWithAttributes)
build!(::EmulationModel)
run!(::EmulationModel)
solve!(::Int, ::EmulationModel{<:EmulationProblem}, ::Dates.DateTime, ::SimulationStore)
```

```@raw html
&nbsp;
&nbsp;
```

* * *

## Service Models

List of structures and methods for Service models

```@docs
ServiceModel
```

```@raw html
&nbsp;
&nbsp;
```

* * *

## Simulation Models

Refer to the [Simulations Page](@ref running_a_simulation) to explanations on how to setup a Simulation, with Sequencing and Feedforwards.

```@docs
InitialCondition
SimulationModels
SimulationSequence
Simulation
Simulation(::AbstractString, ::Dict)
build!(::Simulation)
execute!(::Simulation)
```

```@autodocs
Modules = [PowerSimulations]
Pages   = ["simulation_partitions.jl",
           ]
Order = [:type, :function]
Public = true
Private = false
```

```@raw html
&nbsp;
&nbsp;
```

## Chronology Models

```@autodocs
Modules = [PowerSimulations]
Pages   = ["initial_condition_chronologies.jl",
           ]
Order = [:type, :function]
Public = true
Private = false
```

* * *

## Variables

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
EnergyVariable
ActivePowerOutVariable
ActivePowerInVariable
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

* * *

## Constraints

### Common Constraints

```@docs
PieceWiseLinearCostConstraint

```

### Network Constraints

```@docs
CopperPlateBalanceConstraint
NodalBalanceActiveConstraint
NodalBalanceReactiveConstraint
AreaParticipationAssignmentConstraint
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

* * *

## Parameters

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

## Results

### Acessing Optimization Model

```@autodocs
Modules = [PowerSimulations]
Pages   = ["optimization_container.jl",
            "optimization_debugging.jl"
           ]
Order = [:type, :function]
Public = true
Private = false
```

### Accessing Problem Results

```@autodocs
Modules = [PowerSimulations]
Pages   = ["operation/problem_results.jl",
           ]
Order = [:type, :function]
Public = true
Private = false
```

### Accessing Simulation Results

```@autodocs
Modules = [PowerSimulations]
Pages   = ["simulation_results.jl",
            "simulation_problem_results.jl",
            "simulation_partition_results.jl",
            "hdf_simulation_store.jl"
           ]
Order = [:type, :function]
Public = true
Private = false
```

## Simulation Recorder

```@autodocs
Modules = [PowerSimulations]
Pages   = ["utils/recorder_events.jl",
           ]
Order = [:type, :function]
Public = true
Private = false
```
