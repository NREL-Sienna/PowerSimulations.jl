# `PowerSystems.Branch` Formulations

!!! note
    The usage of reactive power variables and constraints will depend on the network model used, i.e. if it uses (or not) reactive power. If the network model is purely active power based, then no variables and constraints related to reactive power are created. For the sake of completion, if the formulation allows the usage of reactive power it will be included.

### Table of contents

1. [`StaticBranch`](#StaticBranch)
2. [`StaticBranchBounds`](#StaticBranchBounds)
3. [`StaticBranchUnbounded`](#StaticBranchUnbounded)
4. [`HVDCTwoTerminalUnbounded`](#HVDCTwoTerminalUnbounded)
5. [`HVDCTwoTerminalLossless`](#HVDCTwoTerminalLossless)
6. [`HVDCTwoTerminalDispatch`](#HVDCTwoTerminalDispatch)
7. [Valid configurations](#Valid-configurations)

## `StaticBranch`

Formulation valid for `PTDFPowerModel` Network model

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
&  f_t - f_t^\text{sl,up} \le R^\text{max},\quad \forall t \in \{1,\dots, T\} \\
&  f_t + f_t^\text{sl,lo} \le -R^\text{max},\quad \forall t \in \{1,\dots, T\} \\
\end{aligned}
```
on which ``\text{PTDF}`` is the ``N \times B`` system Power Transfer Distribution Factors (PTDF) matrix, and ``\text{Bal}_{i,t}`` is the active power bus balance expression (i.e. ``\text{Generation}_{i,t} - \text{Demand}_{i,t}``) at bus ``i`` at time-step ``t``. 

---

## `StaticBranchBounds`

Formulation valid for `PTDFPowerModel` Network model

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

## `StaticBranchUnbounded`

Formulation valid for `PTDFPowerModel` Network model

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

## `HVDCTwoTerminalUnbounded`

Formulation valid for `PTDFPowerModel` Network model

```@docs
HVDCTwoTerminalUnbounded
```

This model assumes that it can transfer power from two AC buses without losses and no limits.

**Variables:**

- [`FlowActivePowerVariable`](@ref):
  - Bounds: ``\left(-\infty,\infty\right)``
  - Symbol: ``f``


**Objective:**

No cost is added to the objective function.

**Expressions:**

The variable `FlowActivePowerVariable` ``f`` is added to the nodal balance expression `ActivePowerBalance`, by adding the flow ``f`` in the receiving bus and subtracting it from the sending bus. This is used then to compute the AC flows using the PTDF equation.

**Constraints:**

No constraints are added.


---

## `HVDCTwoTerminalLossless`

Formulation valid for `PTDFPowerModel` Network model

```@docs
HVDCTwoTerminalLossless
```

This model assumes that it can transfer power from two AC buses without losses.

**Variables:**

- [`FlowActivePowerVariable`](@ref):
  - Bounds: ``\left(-\infty,\infty\right)``
  - Symbol: ``f``


**Static Parameters**

- ``R^\text{from,min}`` = `PowerSystems.get_active_power_limits_from(branch).min`
- ``R^\text{from,max}`` = `PowerSystems.get_active_power_limits_from(branch).max`
- ``R^\text{to,min}`` = `PowerSystems.get_active_power_limits_to(branch).min`
- ``R^\text{to,max}`` = `PowerSystems.get_active_power_limits_to(branch).max`

**Objective:**

No cost is added to the objective function.

**Expressions:**

The variable `FlowActivePowerVariable` ``f`` is added to the nodal balance expression `ActivePowerBalance`, by adding the flow ``f`` in the receiving bus and subtracting it from the sending bus. This is used then to compute the AC flows using the PTDF equation.

**Constraints:**

```math
\begin{align*}
&  R^\text{min} \le f_t  \le R^\text{max},\quad \forall t \in \{1,\dots, T\} \\
\end{align*}
```
where:
```math
\begin{align*}
&  R^\text{min} = \begin{cases}
			\min\left(R^\text{from,min}, R^\text{to,min}\right), & \text{if } R^\text{from,min} \ge 0 \text{ and } R^\text{to,min} \ge 0 \\
      \max\left(R^\text{from,min}, R^\text{to,min}\right), & \text{if } R^\text{from,min} \le 0 \text{ and } R^\text{to,min} \le 0 \\
      R^\text{from,min},& \text{if } R^\text{from,min} \le 0 \text{ and } R^\text{to,min} \ge 0 \\
      R^\text{to,min},& \text{if } R^\text{from,min} \ge 0 \text{ and } R^\text{to,min} \le 0
		 \end{cases}
\end{align*}
```
and
```math
\begin{align*}
&  R^\text{max} = \begin{cases}
			\min\left(R^\text{from,max}, R^\text{to,max}\right), & \text{if } R^\text{from,max} \ge 0 \text{ and } R^\text{to,max} \ge 0 \\
      \max\left(R^\text{from,max}, R^\text{to,max}\right), & \text{if } R^\text{from,max} \le 0 \text{ and } R^\text{to,max} \le 0 \\
      R^\text{from,max},& \text{if } R^\text{from,max} \le 0 \text{ and } R^\text{to,max} \ge 0 \\
      R^\text{to,max},& \text{if } R^\text{from,max} \ge 0 \text{ and } R^\text{to,max} \le 0
		 \end{cases}
\end{align*}
```

---


## `HVDCTwoTerminalDispatch` 

Formulation valid for `PTDFPowerModel` Network model

```@docs
HVDCTwoTerminalDispatch
```

**Variables**

- [`FlowActivePowerToFromVariable`](@ref):
  - Symbol: ``f^\text{to-from}``
- [`FlowActivePowerFromToVariable`](@ref):
  - Symbol: ``f^\text{from-to}``
- [`HVDCLosses`](@ref):
  - Symbol: ``\ell``
- [`HVDCFlowDirectionVariable`](@ref)
  - Bounds: ``\{0,1\}``
  - Symbol: ``u^\text{dir}``

**Static Parameters**

- ``R^\text{from,min}`` = `PowerSystems.get_active_power_limits_from(branch).min`
- ``R^\text{from,max}`` = `PowerSystems.get_active_power_limits_from(branch).max`
- ``R^\text{to,min}`` = `PowerSystems.get_active_power_limits_to(branch).min`
- ``R^\text{to,max}`` = `PowerSystems.get_active_power_limits_to(branch).max`
- ``L_0`` = `PowerSystems.get_loss(branch).l0`
- ``L_1`` = `PowerSystems.get_loss(branch).l1`

**Objective:**

No cost is added to the objective function.

**Expressions:**

Each `FlowActivePowerToFromVariable` ``f^\text{to-from}`` and `FlowActivePowerFromToVariable` ``f^\text{from-to}``  is added to the nodal balance expression `ActivePowerBalance`, by adding the respective flow in the receiving bus and subtracting it from the sending bus. That is,  ``f^\text{to-from}`` adds the flow to the `from` bus, and subtracts the flow from the `to` bus, while ``f^\text{from-to}`` adds the flow to the `to` bus, and subtracts the flow from the `from` bus  This is used then to compute the AC flows using the PTDF equation.

In addition, the `HVDCLosses` are subtracted to the `from` bus in the `ActivePowerBalance` expression. 

**Constraints:**

```math
\begin{align*}
&  R^\text{from,min} \le f_t^\text{from-to}  \le R^\text{from,max}, \forall t \in \{1,\dots, T\} \\
&  R^\text{to,min} \le f_t^\text{to-from}  \le R^\text{to,max},\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{to-from} - f_t^\text{from-to} \le L_1 \cdot f_t^\text{to-from} - L_0,\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{from-to} - f_t^\text{to-from} \ge L_1 \cdot f_t^\text{from-to} + L_0,\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{from-to} - f_t^\text{to-from} \ge - M^\text{big} (1 - u^\text{dir}_t),\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{to-from} - f_t^\text{from-to} \ge - M^\text{big} u^\text{dir}_t,\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{to-from} - f_t^\text{from-to} \le \ell_t,\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{from-to} - f_t^\text{to-from} \le \ell_t,\quad \forall t \in \{1,\dots, T\} 
\end{align*}
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
filter!(x -> (x["device_type"] <: Branch) && (x["device_type"] != TModelHVDCLine), combos)
combo_table = DataFrame(
    "Valid DeviceModel" => ["`DeviceModel($(c["device_type"]), $(c["formulation"]))`" for c in combos],
    "Device Type" => ["[$(c["device_type"])](https://nrel-Sienna.github.io/PowerSystems.jl/stable/model_library/generated_$(c["device_type"])/)" for c in combos],
    "Formulation" => ["[$(c["formulation"])](@ref)" for c in combos],
    )
mdtable(combo_table, latex = false)
```