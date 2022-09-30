# `PowerSystems.Storage` Formulations

Valid `DeviceModel`s for subtypes of `Storage` include the following:

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.generate_device_formulation_combinations()
filter!(x -> x["device_type"] <: Storage, combos)
combo_table = DataFrame(
    "Valid DeviceModel" => ["`DeviceModel($(c["device_type"]), $(c["formulation"]))`" for c in combos],
    "Device Type" => ["[$(c["device_type"])](https://nrel-siip.github.io/PowerSystems.jl/stable/model_library/generated_$(c["device_type"])/)" for c in combos],
    "Formulation" => ["[$(c["formulation"])](@ref)" for c in combos],
    )
mdtable(combo_table, latex = false)
```

---

## `BookKeeping`

```@docs
BookKeeping
```

**Variables:**

- [`ActivePowerInVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `-1 * PowerSystems.get_active_power(device)`
- [`ActivePowerOutVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_reactive_power(device)`
- [`EnergyVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_initial_storage(device)`
- [`ReservationVariable`](@ref):
  - only included if `DeviceModel(HydroPumpedStorage, HydroDispatchPumpedStorage; attributes = Dict(reservation => true))`
  - Bounds: {0, 1}
  - Default initial value: 1

**Static Parameters:**

- ``Pg^\text{min}`` = `PowerSystems.get_active_power_limits(device).min`
- ``Qg^\text{min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Qg^\text{max}`` = `PowerSystems.get_reactive_power_limits(device).max`
- ``E^\text{max}`` = `PowerSystems.get_storage_capacity(device)`

**Objective:**

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as ``Pg_t``.

**Expressions:**

Adds ``Pg`` and ``Qg`` terms to the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref)

**Constraints:**

```math
\begin{aligned}
&  E_{t+1} = E_t + (Pg^{in}_t - Pg^{out}_t) \cdot \Delta T \\
&  Pg^{in}_t - r * Pg^\text{in, max} \le Pg^\text{in, max} \\
&  Pg^{out}_t + r * Pg^\text{out, max} \le Pg^\text{out, max} \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max} \\
&  E_t \le E^\text{max}
\end{aligned}
```

---

## `EnergyTarget`

```@docs
EnergyTarget
```

**Variables:**

- [`ActivePowerInVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `-1 * PowerSystems.get_active_power(device)`
- [`ActivePowerOutVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_reactive_power(device)`
- [`EnergyVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_initial_storage(device)`
- [`EnergyShortageVariable`](@ref):
  - Bounds: [ , 0.0]
  - Default initial value: 0.0
- [`EnergySurplusVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: 0.0
- [`ReservationVariable`](@ref):
  - only included if `DeviceModel(HydroPumpedStorage, HydroDispatchPumpedStorage; attributes = Dict(reservation => true))`
  - Bounds: {0, 1}
  - Default initial value: 1

**Static Parameters:**

- ``Pg^\text{min}`` = `PowerSystems.get_active_power_limits(device).min`
- ``Qg^\text{min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Qg^\text{max}`` = `PowerSystems.get_reactive_power_limits(device).max`
- ``E^\text{max}`` = `PowerSystems.get_storage_capacity(device)`

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(Storage, EnergyTarget)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as `` Pg_t``,
and objective function terms for [StorageManagementCost](@ref).

**Expressions:**

Adds ``Pg`` and ``Qg`` terms to the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref)

**Constraints:**

```math
\begin{aligned}
&  E_{t+1} = E_t + (Pg^{in}_t - Pg^{out}_t) \cdot \Delta T \\
&  E_t - E^{surplus}_t + E^{shortage}_t = EnergyTargetTimeSeriesParameter_t \\
&  Pg^{in}_t - r * Pg^\text{in, max} \le Pg^\text{in, max} \\
&  Pg^{out}_t + r * Pg^\text{out, max} \le Pg^\text{out, max} \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max}\\
&  E_t \le E^\text{max}
\end{aligned}
```

---

## `BatteryAncillaryServices`

```@docs
BatteryAncillaryServices
```

**Variables:**

- [`ActivePowerInVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `-1 * PowerSystems.get_active_power(device)`
- [`ActivePowerOutVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_reactive_power(device)`
- [`EnergyVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_initial_storage(device)`
- [`ReservationVariable`](@ref):
  - only included if `DeviceModel(HydroPumpedStorage, HydroDispatchPumpedStorage; attributes = Dict(reservation => true))`
  - Bounds: {0, 1}
  - Default initial value: 1

**Static Parameters:**

- ``Pg^\text{min}`` = `PowerSystems.get_active_power_limits(device).min`
- ``Qg^\text{min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Qg^\text{max}`` = `PowerSystems.get_reactive_power_limits(device).max`
- ``E^\text{max}`` = `PowerSystems.get_storage_capacity(device)`

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(Storage, EnergyTarget)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`VariableCost` Options](@ref) where the quantity term is defined as `` Pg_t``,
and objective function terms for [StorageManagementCost](@ref).

**Expressions:**

Adds ``Pg`` and ``Qg`` terms to the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref)

**Constraints:**

```math
\begin{aligned}
&  E_{t+1} = E_t + (Pg^{in}_t - Pg^{out}_t) \cdot \Delta T \\
&  E_t - E^{surplus}_t + E^{shortage}_t = EnergyTargetTimeSeriesParameter_t \\
&  Pg^{in}_t - r * Pg^\text{in, max} \le Pg^\text{in, max} \\
&  Pg^{out}_t + r * Pg^\text{out, max} \le Pg^\text{out, max} \\
&  Qg^\text{min} \le Qg_t \le Qg^\text{max}\\
&  E_t \le E^\text{max}
\end{aligned}
```
