# Glossary

## Simulation Sequence Components

**cache:** Cache is the storage of the solution of a variable from a stage to be used by other stages in the simulation

**chronology:** The vertical inter-stage relationship dictating how variable results impact the next stage's variable parameters.
- Example: `feedforward_chronologies = Dict(("stage-1" => "stage-2") => Synchronize(periods = 24))`

**feedforward:** The variable that is used as a parameter for a later stage.
- Example: `feedforward = Dict(("stage-2", :devices, :Generators) => SemiContinuousFF(binary_from_stage = PSI.ON, affected_variables = [PSI.ACTIVE_POWER])`

**horizons:** The integer count of resolution time periods for a full step resolution of the simulation. *(Horizon = 12) x (resolution = 1 Hour) = 12 Hours*
- Example: `horizons = Dict("stage-1" => 24, "stage-2" => 12)`

**initial condition chronology:** The structure dictating how initial conditions get updated from previous results in the simulation.
- Example: `ini_cond_chronology = InterStageChronology()`

**intervals:** The increment of time per stage in each simulation solve, and how results get fed forward into initial conditions between intervals.
- Example: `intervals = Dict("UC" => (Hour(24), Consecutive()), "ED" => (Hour(1), Consecutive()))`

**Operations Problem** A single-step optimization problem.

**Simulations Problem:** A multi-step and/or multi-stage optimization problem.

**order:** The order of stages in the simulation.
- Example: `order = Dict(1 => "stage-1", 2 => "stage-2")`

**problem:** The optimization problem populated with the specific system to be solved.

**step resolution:** The time period representing the time length of the whole simulation before it repeats.
- Example: `step_resolution = Hour(24)`

**template:** The structure of the problem to be solved, without the actual system data that makes it a populated problem.

Time Increments:
***Resolution ≤ Interval ≤ Step Resolution***