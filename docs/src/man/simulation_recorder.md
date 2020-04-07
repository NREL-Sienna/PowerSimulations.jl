## Simulation Recorder

PowerSimulations provides the ability to record structured data as events
during a simulation. These events can be post-processed to help debug problems.

By default only SimulationStepEvent and SimulationStageEvent are recorded.  Here is an example.

Suppose a simulation is run in the directory ./output.

Assume that setup commands have been run:

```julia
using PowerSimulations
const PSI = PowerSimulations
```

Note that for all functions below you can optionally specify a function to filter events.
The function must accept the event type and return true or false.

### Show all events of type PSI.SimulationStepEvent

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


### Show events of type PSI.SimulationStageEvent for a specific step and stage.

```julia
show_simulation_events(
    PSI.SimulationStageEvent,
    "./output/aggregation/1",
    x -> x.step == 1 && x.stage == 2 && x.status == "start"
)
┌──────────────────────┬─────────────────────┬──────┬───────┬────────┐
│                 name │     simulation_time │ step │ stage │ status │
├──────────────────────┼─────────────────────┼──────┼───────┼────────┤
│ SimulationStageEvent │ 2024-01-01T00:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T00:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T01:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T02:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T03:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T04:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T05:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T06:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T07:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T08:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T09:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T10:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T11:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T12:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T13:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T14:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T15:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T16:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T17:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T18:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T19:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T20:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T21:00:00 │    1 │     2 │  start │
│ SimulationStageEvent │ 2024-01-01T22:00:00 │    1 │     2 │  start │
└──────────────────────┴─────────────────────┴──────┴───────┴────────┘
```

### Enable other recorder events

Other types of recorder events can be enabled with a possible performance impact. To do this
pass in the specific recorder names to be enabled when you call build.

```julia
sim = Simulation(...)
recorders = [:simulation]
build!(sim; recorders = recorders)
execute!(sim)
```

Now we can examine InitialConditionUpdateEvents for specific steps and stages.

```julia
show_simulation_events(
    PSI.InitialConditionUpdateEvent,
    "./output/aggregation/1",
    x -> x.initial_condition_type == "DeviceStatus";
    step = 2,
    stage = 1
)
┌─────────────────────────────┬─────────────────────┬────────────────────────┬─────────────────┬─────────────┬─────┬──────────────┐
│                        name │     simulation_time │ initial_condition_type │     device_type │ device_name │ val │ stage_number │
├─────────────────────────────┼─────────────────────┼────────────────────────┼─────────────────┼─────────────┼─────┼──────────────┤
│ InitialConditionUpdateEvent │ 2024-01-02T00:00:00 │           DeviceStatus │ ThermalStandard │    Solitude │ 0.0 │            1 │
│ InitialConditionUpdateEvent │ 2024-01-02T00:00:00 │           DeviceStatus │ ThermalStandard │   Park City │ 1.0 │            1 │
│ InitialConditionUpdateEvent │ 2024-01-02T00:00:00 │           DeviceStatus │ ThermalStandard │        Alta │ 1.0 │            1 │
│ InitialConditionUpdateEvent │ 2024-01-02T00:00:00 │           DeviceStatus │ ThermalStandard │    Brighton │ 1.0 │            1 │
│ InitialConditionUpdateEvent │ 2024-01-02T00:00:00 │           DeviceStatus │ ThermalStandard │    Sundance │ 0.0 │            1 │
└─────────────────────────────┴─────────────────────┴────────────────────────┴─────────────────┴─────────────┴─────┴──────────────┘
```

### Show the wall time with your events
Sometimes you might want to see how the events line up with the wall time.

```julia
show_simulation_events(
           PSI.InitialConditionUpdateEvent,
           "./output/aggregation/1",
           x -> x.initial_condition_type == "DeviceStatus";
           step = 2,
           stage = 1,
           wall_time = true
       )
┌─────────────────────────┬─────────────────────────────┬─────────────────────┬────────────────────────┬─────────────────┬─────────────┬─────┬──────────────┐
│               timestamp │                        name │     simulation_time │ initial_condition_type │     device_type │ device_name │ val │ stage_number │
├─────────────────────────┼─────────────────────────────┼─────────────────────┼────────────────────────┼─────────────────┼─────────────┼─────┼──────────────┤
│ 2020-04-07T15:08:32.711 │ InitialConditionUpdateEvent │ 2024-01-02T00:00:00 │           DeviceStatus │ ThermalStandard │    Solitude │ 0.0 │            1 │
│ 2020-04-07T15:08:32.711 │ InitialConditionUpdateEvent │ 2024-01-02T00:00:00 │           DeviceStatus │ ThermalStandard │   Park City │ 1.0 │            1 │
│ 2020-04-07T15:08:32.711 │ InitialConditionUpdateEvent │ 2024-01-02T00:00:00 │           DeviceStatus │ ThermalStandard │        Alta │ 1.0 │            1 │
│ 2020-04-07T15:08:32.711 │ InitialConditionUpdateEvent │ 2024-01-02T00:00:00 │           DeviceStatus │ ThermalStandard │    Brighton │ 1.0 │            1 │
│ 2020-04-07T15:08:32.711 │ InitialConditionUpdateEvent │ 2024-01-02T00:00:00 │           DeviceStatus │ ThermalStandard │    Sundance │ 0.0 │            1 │
└─────────────────────────┴─────────────────────────────┴─────────────────────┴────────────────────────┴─────────────────┴─────────────┴─────┴──────────────┘
```
