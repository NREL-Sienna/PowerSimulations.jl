# `ThermalGen` Formulations

Thermal generation formulations define the optimization models that describe thermal unit operations in different operational settings, such as economic dispatch and unit commitment.


!!! note
    Thermal units can include multiple terms added to the objective function, such as no-load cost, turn-on/off cost, fixed cost and variable cost. In addition, variable costs can be linear, quadratic or piecewise-linear formulations. These methods are properly described in the cost function document: TODO. 


!!! note
    The usage of reactive power variables and constraints will depend on the network model used, i.e. if it uses (or not) reactive power. If the network model is purely active power based, then no variables and constraints related to reactive power are created. For the sake of completion, if the formulation allows the usage of reactive power it will be included.

!!! note
    Reserve variables for services are not included in the formulation, albeit their inclusion change the variables, expressions, constraints and objective functions created. A detailed description of the implications in the optimization models is described in the [Service formulation](@ref service_formulation) section.

---

## `ThermalBasicDispatch`

```@docs
ThermalBasicDispatch
```
**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Symbol: ``p^\text{th}``
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Symbol: ``q^\text{th}``

**Static Parameters:**

- ``P^\text{th,min}`` = `PowerSystems.get_active_power_limits(device).min`
- ``P^\text{th,max}`` = `PowerSystems.get_active_power_limits(device).max`
- ``Q^\text{th,min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Q^\text{th,max}`` = `PowerSystems.get_reactive_power_limits(device).max`

**Objective:**

Add a cost to the objective function depending on the defined cost structure of the thermal unit by adding it to its `ProductionCostExpression`.

**Expressions:**

Adds ``p^\text{th}`` to the `ActivePowerBalance` expression and ``q^\text{th}`` to the `ReactivePowerBalance`, to be used in the supply-balance constraint depending on the network model used.

**Constraints:**

For each thermal unit creates the range constraints for its active and reactive power depending on its static parameters.

```math
\begin{align}
&  P^\text{th,min} \le p^\text{th}_t \le P^\text{th,max}, \quad \forall t\in \{1, \dots, T\} \\
&  Q^\text{th,min} \le q^\text{th}_t \le Q^\text{th,max}, \quad \forall t\in \{1, \dots, T\} 
\end{align}
```

---

## `ThermalCompactDispatch`

```@docs
ThermalCompactDispatch
```

**Variables:**

- [`PowerAboveMinimumVariable`](@ref):
  - Bounds: [0.0, ]
  - Symbol: ``\Delta p^\text{th}``
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Symbol: ``q^\text{th}``

**Auxiliary Variables:**
- [`PowerOutput`](@ref):
  - Symbol: ``P^\text{th}``
  - Definition: ``P^\text{th} = \text{on}^\text{th}P^\text{min} + \Delta p^\text{th}``

**Static Parameters:**

- ``P^\text{th,min}`` = `PowerSystems.get_active_power_limits(device).min`
- ``P^\text{th,max}`` = `PowerSystems.get_active_power_limits(device).max`
- ``Q^\text{th,min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Q^\text{th,max}`` = `PowerSystems.get_reactive_power_limits(device).max`
- ``R^\text{th,up}`` = `PowerSystems.get_ramp_limits(device).up`
- ``R^\text{th,dn}`` = `PowerSystems.get_ramp_limits(device).down`

**Variable Value Parameters:**

- ``\text{on}^\text{th}``: Used in feedforwards to define if the unit is on/off at each time-step from another problem. If no feedforward is used, the parameter takes a {0,1} value if the unit is available or not.

**Objective:**

Add a cost to the objective function depending on the defined cost structure of the thermal unit by adding it to its `ProductionCostExpression`.

**Expressions:**

Adds ``\text{on}^\text{th}P^\text{th,min} + \Delta p^\text{th}`` to the `ActivePowerBalance` expression and ``q^\text{th}`` to the `ReactivePowerBalance`, to be used in the supply-balance constraint depending on the network model used.

**Constraints:**

For each thermal unit creates the range constraints for its active and reactive power depending on its static parameters. It also implements ramp constraints for the active power variable.

```math
\begin{align}
&  0 \le \Delta p^\text{th}_t \le \text{on}^\text{th}_t\left(P^\text{th,max} - P^\text{th,min}\right), \quad \forall t\in \{1, \dots, T\} \\
&  \text{on}^\text{th}_t Q^\text{th,min} \le q^\text{th}_t \le \text{on}^\text{th}_t Q^\text{th,max}, \quad \forall t\in \{1, \dots, T\}  \\
& -R^\text{th,dn} \le \Delta p_1^\text{th} - \Delta p^\text{th, init} \le R^\text{th,up} \\
& -R^\text{th,dn} \le \Delta p_t^\text{th} - \Delta p_{t-1}^\text{th} \le R^\text{th,up}, \quad \forall  t\in \{2, \dots, T\}
\end{align}
```

---

## `ThermalDispatchNoMin`

```@docs
ThermalDispatchNoMin
```

**Variables:**

- [`ActivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Symbol: ``p^\text{th}``
- [`ReactivePowerVariable`](@ref):
  - Bounds: [0.0, ]
  - Symbol: ``q^\text{th}``

**Static Parameters:**

- ``P^\text{th,max}`` = `PowerSystems.get_active_power_limits(device).max`
- ``Q^\text{th,min}`` = `PowerSystems.get_reactive_power_limits(device).min`
- ``Q^\text{th,max}`` = `PowerSystems.get_reactive_power_limits(device).max`

**Objective:**

Add a cost to the objective function depending on the defined cost structure of the thermal unit by adding it to its `ProductionCostExpression`.

**Expressions:**

Adds ``p^\text{th}`` to the `ActivePowerBalance` expression and ``q^\text{th}`` to the `ReactivePowerBalance`, to be used in the supply-balance constraint depending on the network model used.

**Constraints:**

For each thermal unit creates the range constraints for its active and reactive power depending on its static parameters.

```math
\begin{align}
&  0 \le p^\text{th}_t \le P^\text{th,max}, \quad \forall t\in \{1, \dots, T\} \\
&  Q^\text{th,min} \le q^\text{th}_t \le Q^\text{th,max}, \quad \forall t\in \{1, \dots, T\} 
\end{align}
```

---

## `ThermalStandardDispatch`

```@docs
ThermalStandardDispatch
```

TODO

---

## `ThermalBasicCompactUnitCommitment`

```@docs
ThermalBasicCompactUnitCommitment
```

TODO

---

## `ThermalCompactUnitCommitment`

```@docs
ThermalCompactUnitCommitment
```

TODO

---

## `ThermalMultiStartUnitCommitment`

```@docs
ThermalMultiStartUnitCommitment
```

TODO

---

## `ThermalBasicUnitCommitment`

```@docs
ThermalBasicUnitCommitment
```

TODO

---

## `ThermalStandardUnitCommitment`

```@docs
ThermalStandardUnitCommitment
```

TODO

---

Valid `DeviceModel`s for subtypes of `ThermalGen` include the following:

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.generate_device_formulation_combinations()
filter!(x -> x["device_type"] <: ThermalGen, combos)
combo_table = DataFrame(
    "Valid DeviceModel" => ["`DeviceModel($(c["device_type"]), $(c["formulation"]))`" for c in combos],
    "Device Type" => ["[$(c["device_type"])](https://nrel-Sienna.github.io/PowerSystems.jl/stable/model_library/generated_$(c["device_type"])/)" for c in combos],
    "Formulation" => ["[$(c["formulation"])](@ref)" for c in combos],
    )
mdtable(combo_table, latex = false)
```
