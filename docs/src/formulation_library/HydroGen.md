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

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as `` Pg_t``.

**Constraints:**

```math
\begin{aligned}
&  Pg^\text{min} \le Pg_t \le ActivePowerTimeSeriesParameter_t \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max}
\end{aligned}
```

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

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as ``Pg_t``.
TODO: add slack terms

**Constraints:**

TODOl: add slack terms

```math
\begin{aligned}
&  Pg^\text{min} \le Pg_t \le Pg^\text{max} \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max} \\
&  \sum_{t = 1}^N(Pg_t) \cdot \Delta T \le \sum_{t = 1}^N(EnergyBudgetTimeSeriesParameter_t) \cdot \Delta T
\end{aligned}
```

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

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as ``Pg_t``.
TODO: add slack terms

**Constraints:**

TODO: Add slack terms

```math
\begin{aligned}
&  E_{t+1} = E_t + (InflowTimeSeriesParameter_t - S_t - Pg_t) \cdot \Delta T \\
&  Pg^\text{min} \le Pg_t \le Pg^\text{max} \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max}
\end{aligned}
```

Future releases will also implement a requirement of the energy at the last time point ``N``:

```math
\begin{aligned}
& E_N \ge E^\text{requirement}
\end{aligned}
```

## `HydroCommitmentReservoirBudget`

```@docs
HydroCommitmentReservoirBudget
```

**Variables:**

**Static Parameters:**

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

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as ``Pg_t``.
TODO: add slack and UC terms

**Constraints:**

Similar to the dispatch formulation, but considering a binary variable ``u_t \in \{0, 1\}`` with semi continuous constraints for both active and reactive power:

```math
\begin{aligned}
&  \sum_{t = 1}^N P_t \cdot \Delta T \le E^\text{budget} \\
&  P_t - u_t P^\text{max} \le 0 \\
&  P_t - u_t P^\text{min} \ge 0 \\
&  Q_t - u_t Q^\text{max} \le 0 \\
&  Q_t - u_t Q^\text{min} \ge 0
\end{aligned}
```

## `HydroCommitmentReservoirStorage`

```@docs
HydroCommitmentReservoirStorage
```

**Variables:**

**Static Parameters:**

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

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as ``Pg_t``.
TODO: add slack and UC terms

**Constraints:**

TODO: Add slack and UC terms

```math
\begin{aligned}
&  E_{t+1} = E_t + (InflowTimeSeriesParameter_t - S_t - Pg_t) \cdot \Delta T \\
&  Pg^\text{min} \le Pg_t \le Pg^\text{max} \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max}
\end{aligned}
```

Future releases will also implement a requirement of the energy at the last time point ``N``:

```math
\begin{aligned}
& E_N \ge E^\text{requirement}
\end{aligned}
```

Similar to the dispatch formulation, but considering a binary variable ``u_t \in \{0, 1\}`` with semi continuous constraints for both active and reactive power:

```math
\begin{aligned}
&  E_{t+1} = E_t + (I_t - S_t - P_t)\Delta T \\
&  P_t - u_t P^\text{max} \le 0 \\
&  P_t - u_t P^\text{min} \ge 0 \\
&  Q_t - u_t Q^\text{max} \le 0 \\
&  Q_t - u_t Q^\text{min} \ge 0
\end{aligned}
```

## `HydroCommitmentRunOfRiver`

```@docs
HydroCommitmentRunOfRiver
```

**Variables:**

**Static Parameters:**

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

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as ``Pg_t``.
TODO: add UC terms

**Constraints:**

Similar to the dispatch formulation, but considering a binary variable ``u_t \in \{0, 1\}`` with semi continuous constraints for both active and reactive power:

```math
\begin{aligned}
&  P_t \le \eta_t P^\text{max}\\
&  P_t - u_t P^\text{max} \le 0 \\
&  P_t - u_t P^\text{min} \ge 0 \\
&  Q_t - u_t Q^\text{max} \le 0 \\
&  Q_t - u_t Q^\text{min} \ge 0
\end{aligned}
```
