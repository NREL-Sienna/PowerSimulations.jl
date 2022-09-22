# `PowerSystems.RenewableGen` Formulations

Valid `DeviceModel`s for subtypes of `RenewableGen` include the following:

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.generate_device_formulation_combinations()
filter!(x -> x["device_type"] <: RenewableGen, combos)
combo_table = DataFrame(
    "Valid DeviceModels" => ["`DeviceModel($(c["device_type"]), $(c["formulation"]))`" for c in combos],
    "Formulation" => ["[$(c["formulation"])](@ref)" for c in combos],
    )
mdtable(combo_table, latex = false)
```

---

## `RenewableFullDispatch`

```@docs
RenewableFullDispatch
```

**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref): 
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_reactive_power(device)`

**Service Variables:**

- [`ActivePowerReserveVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: 0.0

**Static Parameters:**

- ``Pg^\text{min}`` = `PowerSystems.get_active_power_limits(device).min`
- ``Qg^\text{min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Qg^\text{max}`` = `PowerSystems.get_reactive_power_limits(device).max`

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(RenewableGen, RenewableFullDispatch)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined by ``ActivePowerTimeSeriesParameter_t - Pg_t``

**Constraints:**

```math
\begin{aligned}
&  Pg_t + \sum_{i \in S^{\uparrow}}{Pr^{\uparrow}_{i,t}} \le ActivePowerTimeSeriesParameter_t \\
&  Pg_t - \sum_{i \in S^{\downarrow}}{Pr^{\downarrow}_{i,t}} \ge Pg^\text{min} \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max}
\end{aligned}
```

---

## `RenewableConstantPowerFactor`

```@docs
RenewableConstantPowerFactor
```

**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0,]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref): 
  - Bounds: [0,]
  - Default initial value: `PowerSystems.get_reactive_power(device)`

**Service Variables:**

- [`ActivePowerReserveVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: 0.0

**Static Parameters:**

- ``Pg^\text{min}`` = `PowerSystems.get_active_power_limits(device).min`
- ``Qg^\text{min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Qg^\text{max}`` = `PowerSystems.get_reactive_power_limits(device).max`
- ``pf`` = `PowerSystems.get_power_factor(device)`

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(RenewableGen, RenewableConstantPowerFactor)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined by ``ActivePowerTimeSeriesParameter_t - Pg_t``

**Constraints:**

```math
\begin{aligned}
&  Pg_t + \sum_{i \in S^{\uparrow}}{Pr^{\uparrow}_{i,t}} \le ActivePowerTimeSeriesParameter_t \\
&  Pg_t - \sum_{i \in S^{\downarrow}}{Pr^{\downarrow}_{i,t}} \ge Pg^\text{min} \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max} \\
&  Qg_t = pf * Pg_t
\end{aligned}
```