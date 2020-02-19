# Glossary

## Simulation Sequence Components

**cache:** Dictionary of each stage and its vector of caches. Each cache tracks the last time status of a device changed in a simulation.

**feed_forward:** The vertical inter-stage relationship between the binary variable status of one stage and the affected variables of the next stage.
- Example: `feedforward = Dict(("stage-2", :devices, :Generators) => SemiContinuousFF(binary_from_stage = PSI.ON, affected_variables = [PSI.ACTIVE_POWER])`

**feed_forward_chronologies:** The vertical inter-stage relationship dictating how variable results impact the next stage's variable parameters.
- Example: `feedforward_chronologies = Dict(("stage-1" => "stage-2") => Synchronize(periods = 24))`

**horizons:** The integer count of resolution time periods for a full step resolution of the simulation. *(Horizon = 12) x (resolution = 1 Hour) = 12 Hours*
- Example: `horizons = Dict("stage-1" => 24, "stage-2" => 12)`

**ini_cond_chronology:** The structure dictating how initial conditions get updated from previous results in the simulation.
- Example: `ini_cond_chronology = InterStageChronology()`

**intervals:** The increment of time per stage in each simulation solve, and how results get fed forward into initial conditions between intervals.
- Example: `intervals = Dict("UC" => (Hour(24), Consecutive()), "ED" => (Hour(1), Consecutive()))`

**order:** The order of stages in the simulation.
- Example: `order = Dict(1 => "stage-1", 2 => "stage-2")`

**step_resolution:** The time period representing the time length of the whole simulation before it repeats.
- Example: `step_resolution = Hour(24)`

Time Increments:
***Resolution ≤ Interval ≤ Step Resolution***