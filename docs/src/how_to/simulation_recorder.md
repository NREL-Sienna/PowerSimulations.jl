# Simulation Recorder

PowerSimulations.jl provides the ability to record structured data as events
during a simulation. These events can be post-processed to help debug problems.

By default only SimulationStepEvent and ProblemExecutionEvent are recorded.  Here is an example.

Suppose a simulation is run in the directory `./output`.

Assume that setup commands have been run:

```julia
using PowerSimulations
const PSI = PowerSimulations
```

Note that for all functions below you can optionally specify a function to filter events.
The function must accept the event type and return true or false.

## Show all events of type PSI.SimulationStepEvent

```julia
julia> show_simulation_events(PSI.SimulationStepEvent, "./output/aggregation/1")
┌─────────────────────┬─────────────────────┬──────┬────────┐
│                name │     simulation_time │ step │ status │
├─────────────────────┼─────────────────────┼──────┼────────┤
│ SimulationStepEvent │ 2024-01-01T00:00:00 │    1 │  start │
│ SimulationStepEvent │ 2024-01-01T23:00:00 │    1 │   done │
│ SimulationStepEvent │ 2024-01-01T23:00:00 │    2 │  start │
│ SimulationStepEvent │ 2024-01-02T23:00:00 │    2 │   done │
└─────────────────────┴─────────────────────┴──────┴────────┘
```

## Show events of type PSI.ProblemExecutionEvent for a specific step and stage.

```julia
show_simulation_events(
    PSI.ProblemExecutionEvent,
    "./output/aggregation/1",
    x -> x.step == 1 && x.stage == 2 && x.status == "start"
)
┌──────────────────────┬─────────────────────┬──────┬───────┬────────┐
│                 name │     simulation_time │ step │ stage │ status │
├──────────────────────┼─────────────────────┼──────┼───────┼────────┤
│ ProblemExecutionEvent │ 2024-01-01T00:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T00:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T01:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T02:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T03:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T04:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T05:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T06:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T07:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T08:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T09:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T10:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T11:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T12:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T13:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T14:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T15:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T16:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T17:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T18:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T19:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T20:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T21:00:00 │    1 │     2 │  start │
│ ProblemExecutionEvent │ 2024-01-01T22:00:00 │    1 │     2 │  start │
└──────────────────────┴─────────────────────┴──────┴───────┴────────┘
```
