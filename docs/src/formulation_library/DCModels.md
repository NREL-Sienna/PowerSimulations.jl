# DC Models formulations

!!! note
    
    Multi-terminal DC models are still in early stages of development and future versions will add a more comprehensive list of formulations

* * *

## LossLessLine

`LossLessLine` models are used with `PSY.DCBranch` models.

```@docs
LossLessLine
```

**Variables:**

  - [`FlowActivePowerVariable`](@ref):
    
      + Bounds: ``(R^\text{min},R^\text{max})``
      + Symbol: ``f``

**Static Parameters**

  - ``R^\text{from,min}`` = `PowerSystems.get_active_power_limits_from(branch).min`
  - ``R^\text{from,max}`` = `PowerSystems.get_active_power_limits_from(branch).max`
  - ``R^\text{to,min}`` = `PowerSystems.get_active_power_limits_to(branch).min`
  - ``R^\text{to,max}`` = `PowerSystems.get_active_power_limits_to(branch).max`

Then, the minimum and maximum are computed as `R^\text{min} = \min(R^\text{from,min}, R^\text{to,min})` and `R^\text{max} = \min(R^\text{from,max}, R^\text{to,max})`

**Objective:**

No cost is added to the objective function.

**Expressions:**

The variable `FlowActivePowerVariable` ``f`` is added to the nodal balance expression `ActivePowerBalance` for DC Buses, by adding the flow ``f`` in the receiving DC bus and subtracting it from the sending DC bus.

**Constraints:**

No constraints are added to the function.

* * *

## LossLessConverter

Converters are used to interface the AC Buses with DC Buses.

```@docs
LossLessConverter
```

**Variables:**

  - [`ActivePowerVariable`](@ref):
    
      + Bounds: ``(P^\text{min},P^\text{max})``
      + Symbol: ``p``

**Static Parameters:**

  - ``P^\text{min}`` = `PowerSystems.get_active_power_limits(device).min`
  - ``P^\text{max}`` = `PowerSystems.get_active_power_limits(device).max`

**Objective:**

No cost is added to the objective function.

**Expressions:**

The variable `ActivePowerVariable` ``p`` is added positive to the AC balance expression `ActivePowerBalance` for AC Buses, and added negative to `ActivePowerBalance` for DC Buses, balancing both sides.

**Constraints:**

No constraints are added to the function.
