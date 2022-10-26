# Extending Source Code Functionalities

## Enable other recorder events

Other types of recorder events can be enabled with a possible performance impact. To do this
pass in the specific recorder names to be enabled when you call build.

```julia
sim = Simulation(...)
recorders = [:execution]
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

## Show the wall time with your events

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
