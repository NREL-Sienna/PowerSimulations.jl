# `PowerSystems.HydroGen` Formulations

Valid `DeviceModel`s for subtypes of `HydroGen` include the following:

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.generate_device_formulation_combinations()
filter!(x -> x["device_type"] <: HydroGen, combos)
combo_table = DataFrame(
    "Valid DeviceModel" => ["`DeviceModel($(c["device_type"]), $(c["formulation"]))`" for c in combos],
    "Device Type" => ["[$(c["device_type"])](https://nrel-siip.github.io/PowerSystems.jl/stable/model_library/generated_$(c["device_type"])/)" for c in combos],
    "Formulation" => ["[$(c["formulation"])](@ref)" for c in combos],
    )
mdtable(combo_table, latex = false)
```

---

## `HydroDispatchRunOfRiver`

```@docs
HydroDispatchRunOfRiver
```

**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_reactive_power(device)`

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
combos = PowerSimulations.get_default_time_series_names(HydroGen, HydroDispatchRunOfRiver)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as `` Pg``.

**Constraints:**

```math
\begin{aligned}
&  Pg^\text{min} \le Pg_t \le ActivePowerTimeSeriesParameter_t \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max}
\end{aligned}
```

---

## `HydroDispatchPumpedStorage`

```@docs
HydroDispatchPumpedStorage
```

**Variables:**

**Static Parameters:**

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(HydroPumpedStorage, HydroDispatchPumpedStorage)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

**Constraints:**

---

## `HydroDispatchReservoirBudget`

```@docs
HydroDispatchReservoirBudget
```

**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_reactive_power(device)`

**Auxillary Variables:**

- [`EnergyOutput`](@ref) - TODO

**Static Parameters:**

- ``Pg^\text{min}`` = `PowerSystems.get_active_power_limits(device).min`
- ``Pg^\text{max}`` = `PowerSystems.get_active_power_limits(device).max`
- ``Qg^\text{min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Qg^\text{max}`` = `PowerSystems.get_reactive_power_limits(device).max`

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(HydroEnergyReservoir, HydroDispatchReservoirBudget)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as ``Pg``.

**Constraints:**

```math
\begin{aligned}
&  Pg^\text{min} \le Pg_t \le Pg^\text{max} \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max} \\
&  \sum_{t = 1}^N(Pg_t) \cdot \Delta T \le \sum_{t = 1}^N(EnergyBudgetTimeSeriesParameter_t) \cdot \Delta T
\end{aligned}
```

---

## `HydroDispatchReservoirStorage`

```@docs
HydroDispatchReservoirStorage
```

**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_reactive_power(device)`
- [`EnergyVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_initial_storage(device)`
- [`WaterSpillageVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: 0.0
- [`EnergyShortageVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: 0.0
- [`EnergySurplusVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: 0.0

**Auxillary Variables:**

- [`EnergyOutput`](@ref)

**Static Parameters:**

- ``Pg^\text{min}`` = `PowerSystems.get_active_power_limits(device).min`
- ``Pg^\text{max}`` = `PowerSystems.get_active_power_limits(device).max`
- ``Qg^\text{min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Qg^\text{max}`` = `PowerSystems.get_reactive_power_limits(device).max`
- ``Eg^\text{max}`` = `PowerSystems.get_storage_capacity(device)`

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(HydroEnergyReservoir, HydroDispatchReservoirStorage)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as ``Pg``.
TODO: add slack terms

**Constraints:**

```math
\begin{aligned}
&  E_{t+1} = E_t + (InflowTimeSeriesParameter_t - S_t - Pg_t) \cdot \Delta T \\
&  E_t - E^{surplus}_t + E^{shortage}_t = EnergyTargetTimeSeriesParameter_t \\
&  Pg^\text{min} \le Pg_t \le Pg^\text{max} \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max}
\end{aligned}
```

---

## `HydroCommitmentReservoirBudget`

```@docs
HydroCommitmentReservoirBudget
```

**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_reactive_power(device)`
- [`OnVariable`](@ref):
  - Bounds: {0, 1}
  - Default initial value: `PowerSystems.get_status(device)`

**Auxillary Variables:**

- [`EnergyOutput`](@ref) - TODO

**Static Parameters:**

- ``Pg^\text{min}`` = `PowerSystems.get_active_power_limits(device).min`
- ``Pg^\text{max}`` = `PowerSystems.get_active_power_limits(device).max`
- ``Qg^\text{min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Qg^\text{max}`` = `PowerSystems.get_reactive_power_limits(device).max`

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(HydroEnergyReservoir, HydroCommitmentReservoirBudget)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as ``Pg``.

**Constraints:**

```math
\begin{aligned}
&  \sum_{t = 1}^N P_t \cdot \Delta T \le E^\text{budget} \\
&  Pg_t - u_t Pg^\text{max} \le 0 \\
&  Pg_t - u_t Pg^\text{min} \ge 0 \\
&  Qg_t - u_t Qg^\text{max} \le 0 \\
&  Qg_t - u_t Qg^\text{min} \ge 0
\end{aligned}
```

---

## `HydroCommitmentReservoirStorage`

```@docs
HydroCommitmentReservoirStorage
```

**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_reactive_power(device)`
- [`EnergyVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_initial_storage(device)`
- [`WaterSpillageVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: 0.0
- [`EnergyShortageVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: 0.0
- [`EnergySurplusVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: 0.0
- [`OnVariable`](@ref):
  - Bounds: {0, 1}
  - Default initial value: `PowerSystems.get_status(device)`

**Auxillary Variables:**

- [`EnergyOutput`](@ref)

**Static Parameters:**

- ``Pg^\text{min}`` = `PowerSystems.get_active_power_limits(device).min`
- ``Pg^\text{max}`` = `PowerSystems.get_active_power_limits(device).max`
- ``Qg^\text{min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Qg^\text{max}`` = `PowerSystems.get_reactive_power_limits(device).max`
- ``Eg^\text{max}`` = `PowerSystems.get_storage_capacity(device)`

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(HydroEnergyReservoir, HydroCommitmentReservoirStorage)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as ``Pg``.

TODO: add slack terms

**Constraints:**

```math
\begin{aligned}
&  E_{t+1} = E_t + (InflowTimeSeriesParameter_t - S_t - Pg_t) \cdot \Delta T \\
&  E_t - E^{surplus}_t + E^{shortage}_t = EnergyTargetTimeSeriesParameter_t \\
&  Pg_t - u_t Pg^\text{max} \le 0 \\
&  Pg_t - u_t Pg^\text{min} \ge 0 \\
&  Qg_t - u_t Qg^\text{max} \le 0 \\
&  Qg_t - u_t Qg^\text{min} \ge 0
\end{aligned}
```

---

## `HydroCommitmentRunOfRiver`

```@docs
HydroCommitmentRunOfRiver
```

**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_reactive_power(device)`
- [`OnVariable`](@ref):
  - Bounds: {0, 1}
  - Default initial value: `PowerSystems.get_status(device)`

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
combos = PowerSimulations.get_default_time_series_names(HydroGen, HydroCommitmentRunOfRiver)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as ``Pg``.

**Constraints:**

```math
\begin{aligned}
&  Pg_t \le Pg^\text{max}\\
&  Pg_t - u_t Pg^\text{max} \le 0 \\
&  Pg_t - u_t Pg^\text{min} \ge 0 \\
&  Qg_t - u_t Qg^\text{max} \le 0 \\
&  Qg_t - u_t Qg^\text{min} \ge 0
\end{aligned}
```
