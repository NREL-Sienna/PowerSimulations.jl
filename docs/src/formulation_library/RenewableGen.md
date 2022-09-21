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

- ``P_t \geq 0``: active power injected by renewable generator at time ``t`` (MW)
- ``Q_t \geq 0``: reactive power injected by renewable generator at time ``t`` (MW)

**Parameters**

- ``P^\text{max}_t``: maximum active power availability for generator at time ``t`` (MW) - defined by `max_active_power` time series

**Objective**

Creates an objective function term based on the [`VariableCost` Options](@ref) using ``G_t = P^\text{max}_t - P_t``

**Constraints**

```math
\begin{aligned}
&  P^\text{min} \le P_t \le P^\text{max}_t \\
&  Q^\text{min} \le Q_t \le Q^\text{max}
\end{aligned}
```

---

## `RenewableConstantPowerFactor`

```@docs
RenewableConstantPowerFactor
```

**Variables**

- ``P_t \geq 0``: active power injected by renewable generator at time ``t`` (MW)
- ``Q_t \geq 0``: reactive power injected by renewable generator at time ``t`` (MW)

**Parameters**

- ``P^\text{max}_t``: maximum active power availability for generator at time ``t`` (MW) - defined by `max_active_power` time series
- ``pf``: renewable generator power factor (see `PowerSystems.get_power_factor`)

**Objective**

Creates an objective function term based on the [`VariableCost` Options](@ref) using ``G_t = P^\text{max}_t - P_t``

**Constraints**

```math
\begin{align}
&  P^\text{min} \le P_t \le \eta_t P^\text{max} \\
&  Q^\text{min} \le Q_t \le pf * P_t
\end{align}
```