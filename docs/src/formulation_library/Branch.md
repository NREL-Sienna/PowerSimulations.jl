# `PowerSystems.Branch` Formulations

!!! note
    The usage of reactive power variables and constraints will depend on the network model used, i.e. if it uses (or not) reactive power. If the network model is purely active power based, then no variables and constraints related to reactive power are created. For the sake of completion, if the formulation allows the usage of reactive power it will be included.

## `StaticBranch` for `PTDFPowerModel` Network model

```@docs
StaticBranch
```

**Variables:**

- [`FlowActivePowerVariable`](@ref):
  - Bounds: ``(-\infty,\infty)``
  - Symbol: ``f``
If Slack variables are enabled:
- [`FlowActivePowerSlackUpperBound`](@ref):
  - Bounds: [0.0, ]
  - Default proportional cost: 2e5
  - Symbol: ``f^\text{sl,up}``
- [`FlowActivePowerSlackLowerBound`](@ref):
  - Bounds: [0.0, ]
  - Default proportional cost: 2e5
  - Symbol: ``f^\text{sl,lo}``

**Static Parameters**

- ``R^\text{max}`` = `PowerSystems.get_rate(branch)`

**Objective:**

Add a large proportional cost to the objective function if rate constraint slack variables are used ``+ (f^\text{sl,up} + f^\text{sl,lo}) \cdot 2 \cdot 10^5``

**Expressions:**

No expressions are used.

**Constraints:**

For each branch ``b \in \{1,\dots, B\}`` (in a system with ``N`` buses) the constraints are given by: 

```math
\begin{aligned}
&  f_t = \sum_{i=1}^N \text{PTDF}_{i,b} \cdot \text{Bal}_{i,t}, \quad \forall t \in \{1,\dots, T\}\\
&  f_t - f_t^\text{sl,up} \le R^\text{max} \\
&  f_t + f_t^\text{sl,lo} \le -R^\text{max} \\
\end{aligned}
```
on which ``\text{PTDF}`` is the ``N \times B`` system Power Transfer Distribution Factors (PTDF) matrix, and ``\text{Bal}_{i,t}`` is the active power bus balance expression (i.e. ``\text{Generation}_{i,t} - \text{Demand}_{i,t}``) at bus ``i`` at time-step ``t``. 

---

## `StaticBranchBounds` for `PTDFPowerModel` Network model

```@docs
StaticBranchBounds
```

**Variables:**

- [`FlowActivePowerVariable`](@ref):
  - Bounds: ``\left[-R^\text{max},R^\text{max}\right]``
  - Symbol: ``f``

**Static Parameters**

- ``R^\text{max}`` = `PowerSystems.get_rate(branch)`

**Objective:**

No cost is added to the objective function.

**Expressions:**

No expressions are used.

**Constraints:**

For each branch ``b \in \{1,\dots, B\}`` (in a system with ``N`` buses) the constraints are given by: 

```math
\begin{aligned}
&  f_t = \sum_{i=1}^N \text{PTDF}_{i,b} \cdot \text{Bal}_{i,t}, \quad \forall t \in \{1,\dots, T\}
\end{aligned}
```
on which ``\text{PTDF}`` is the ``N \times B`` system Power Transfer Distribution Factors (PTDF) matrix, and ``\text{Bal}_{i,t}`` is the active power bus balance expression (i.e. ``\text{Generation}_{i,t} - \text{Demand}_{i,t}``) at bus ``i`` at time-step ``t``. 

---

## `StaticBranchUnbounded` `PTDFPowerModel` Network model

```@docs
StaticBranchUnbounded
```

- [`FlowActivePowerVariable`](@ref):
  - Bounds: ``(-\infty,\infty)``
  - Symbol: ``f``


**Objective:**

No cost is added to the objective function.

**Expressions:**

No expressions are used.

**Constraints:**

For each branch ``b \in \{1,\dots, B\}`` (in a system with ``N`` buses) the constraints are given by: 

```math
\begin{aligned}
&  f_t = \sum_{i=1}^N \text{PTDF}_{i,b} \cdot \text{Bal}_{i,t}, \quad \forall t \in \{1,\dots, T\}
\end{aligned}
```
on which ``\text{PTDF}`` is the ``N \times B`` system Power Transfer Distribution Factors (PTDF) matrix, and ``\text{Bal}_{i,t}`` is the active power bus balance expression (i.e. ``\text{Generation}_{i,t} - \text{Demand}_{i,t}``) at bus ``i`` at time-step ``t``. 

---

## `HVDCTwoTerminalLossless`

```@docs
HVDCTwoTerminalLossless
```

---

## `HVDCTwoTerminalDispatch`

```@docs
HVDCTwoTerminalDispatch
```

---

## `HVDCTwoTerminalUnbounded`

```@docs
HVDCTwoTerminalUnbounded
```

---

## Valid configurations

Valid `DeviceModel`s for subtypes of `Branch` include the following:

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.generate_device_formulation_combinations()
filter!(x -> x["device_type"] <: Branch, combos)
combo_table = DataFrame(
    "Valid DeviceModel" => ["`DeviceModel($(c["device_type"]), $(c["formulation"]))`" for c in combos],
    "Device Type" => ["[$(c["device_type"])](https://nrel-Sienna.github.io/PowerSystems.jl/stable/model_library/generated_$(c["device_type"])/)" for c in combos],
    "Formulation" => ["[$(c["formulation"])](@ref)" for c in combos],
    )
mdtable(combo_table, latex = false)
```