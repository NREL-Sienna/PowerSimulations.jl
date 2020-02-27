# Glossary

## Simulation Sequence Components

**cache:** Cache is used to store quantities resulting from the solutions of a stage.

**chronology:** The vertical inter-stage relationship dictating how variable results impact the next stage's variable parameters.
- Example: `feedforward_chronologies = Dict(("stage-1" => "stage-2") => Synchronize(periods = 24))` *This chronology uses the first 24 solutions in the horizon to synchronize with 24 executions of stage 2.*

**feedforward:** The variable that is used as a parameter for a later stage.
- Example: `feedforward = Dict(("stage-2", :devices, :Generators) => SemiContinuousFF(binary_from_stage = PSI.ON, affected_variables = [PSI.ACTIVE_POWER])` *This semi-continuous feedforward passes binary results from the first stage to parameters of the active power of the second stage.*

**horizons:** The integer count of resolution time periods for a full step resolution of the simulation. *(Horizon = 12) x (resolution = 1 Hour) = 12 Hours*
- Example: `horizons = Dict("stage-1" => 24, "stage-2" => 12)` *The first stage has a horizon of 24, representing 24 1-hour increments. The second stage has a horizon of 12, representing 12 5-min increments*

**initial condition chronology:** The structure dictating how initial conditions get updated from previous results in the simulation.
- Examples: `ini_cond_chronology = InterStageChronology()`
```julia
1
|
2                   2 ... (x04)
|             ┌----/|
|             |     |
3 --> 3 ... (x12)   3 --> 3 ... (x12)
```

*This represents an inter-stage chronology where the results of each stage feed back into the initial conditions of the stage above it.*

`ini_cond_chronology = IntraStageChronology()`
```julia
1

2 ----------------> 2 ... (x04)

3 --> 3 ... (x12)   3 --> 3 ... (x12)
```
*This represents an intra-stage chronology where the results of each simulation run feed back into the initial conditions of the next simulation for that stage.*


**intervals:** The increment of time per stage in each simulation solve, and how results get fed forward into initial conditions between intervals.
- Example: `intervals = Dict("UC" => (Hour(24), Consecutive()), "ED" => (Hour(1), Consecutive()))`

**Operations Problem** A single-step optimization problem.

**Simulations Problem:** A multi-step and/or multi-stage optimization problem.

**Simulation Sequence:** Simulation Sequence formulates the structure and flow of results through the simulation. It sets up the feedforward and initial condition chronologies, the horizon, intervals, and order.

**Stage:** Each stage represents a formulation of a problem to be solved, such as unit commitment or economic dispatch. Each stage has its own system with a specified time-scale.
- Example:
`"UC" => Stage(GenericOpProblem, template, system, optimizer)`

**problem:** The optimization problem populated with the specific system to be solved.

**step resolution:** The time period representing the time length of the whole simulation before it repeats.
- Example: `step_resolution = Hour(24)`

**template:** The structure of the problem to be solved, without the actual system data that makes it a populated problem.

Time Increments:
***Resolution ≤ Interval ≤ Step Resolution***