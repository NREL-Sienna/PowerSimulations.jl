# `PowerSystems.ElectricLoad` Formulations

Valid `DeviceModel`s for subtypes of `ElectricLoad` include the following:

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.generate_device_formulation_combinations()
filter!(x -> x["device_type"] <: ElectricLoad, combos)
combo_table = DataFrame(
    "Valid DeviceModel" => ["`DeviceModel($(c["device_type"]), $(c["formulation"]))`" for c in combos],
    "Device Type" => ["[$(c["device_type"])](https://nrel-Sienna.github.io/PowerSystems.jl/stable/model_library/generated_$(c["device_type"])/)" for c in combos],
    "Formulation" => ["[$(c["formulation"])](@ref)" for c in combos],
    )
mdtable(combo_table, latex = false)
```

---

## `StaticPowerLoad`

```@docs
StaticPowerLoad
```

**Variables:**

No variables are created

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(ElectricLoad, StaticPowerLoad)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Expressions:**

Subtracts the parameters listed above from the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref network_formulations)

**Constraints:**

No constraints are created

---

## `PowerLoadInterruption`

```@docs
PowerLoadInterruption
```

**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: 0.0
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: 0.0
- [`OnVariable`](@ref):
  - Bounds: {0,1}
  - Default initial value: 1

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(ElectricLoad, PowerLoadInterruption)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`FunctionData` Options](@ref) where the quantity term is defined as ``Pg``.

**Expressions:**

- Adds ``Pg`` and ``Qg`` terms and to the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref network_formulations)
- Subtracts the time series parameters listed above terms from the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref network_formulations)

**Constraints:**

``Pg`` and ``Qg`` represent the "unserved" active and reactive power loads

```math
\begin{aligned}
&  Pg_t \le ActivePowerTimeSeriesParameter_t\\
&  Pg_t - u_t ActivePowerTimeSeriesParameter_t \le 0 \\
&  Qg_t \le ReactivePowerTimeSeriesParameter_t\\
&  Qg_t - u_t ReactivePowerTimeSeriesParameter_t\le 0
\end{aligned}
```

---

## `PowerLoadDispatch`

```@docs
PowerLoadDispatch
```

**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_active_power(device)`
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Default initial value: `PowerSystems.get_reactive_power(device)`

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(ElectricLoad, PowerLoadDispatch)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Objective:**

Creates an objective function term based on the [`FunctionData` Options](@ref) where the quantity term is defined as ``Pg``.

**Expressions:**

- Adds ``Pg`` and ``Qg`` terms and to the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref network_formulations)
- Subtracts the time series parameters listed above terms from the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref network_formulations)

**Constraints:**

``Pg`` and ``Qg`` represent the "unserved" active and reactive power loads

```math
\begin{aligned}
&  Pg_t \le ActivePowerTimeSeriesParameter_t\\
&  Qg_t \le ReactivePowerTimeSeriesParameter_t\\
\end{aligned}
```
