# `PowerSystems.ElectricLoad` Formulations

Electric load formulations define the optimization models that describe load units (demand) mathematical model in different operational settings, such as economic dispatch and unit commitment.

!!! note
    
    The use of reactive power variables and constraints will depend on the network model used, i.e., whether it uses (or does not use) reactive power. If the network model is purely active power-based, reactive power variables and related constraints are not created.

### Table of contents

 1. [`StaticPowerLoad`](#StaticPowerLoad)
 2. [`PowerLoadInterruption`](#PowerLoadInterruption)
 3. [`PowerLoadDispatch`](#PowerLoadDispatch)
 4. [`PowerLoadShift`](#PowerLoadShift)
 5. [Valid configurations](#Valid-configurations)

* * *

## `StaticPowerLoad`

```@docs
StaticPowerLoad
```

**Variables:**

No variables are created

**Time Series Parameters:**

Uses the `max_active_power`  timeseries parameter to determine the demand value at each time-step

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
mdtable(combo_table; latex = false)
```

**Expressions:**

Subtracts the parameters listed above from the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref network_formulations).

**Constraints:**

No constraints are created

* * *

## `PowerLoadInterruption`

```@docs
PowerLoadInterruption
```

**Variables:**

  - [`ActivePowerVariable`](@ref):
    
      + Bounds: [0.0, ]
      + Default initial value: 0.0
      + Symbol: ``p^\text{ld}``

  - [`ReactivePowerVariable`](@ref):
    
      + Bounds: [0.0, ]
      + Default initial value: 0.0
      + Symbol: ``q^\text{ld}``
  - [`OnVariable`](@ref):
    
      + Bounds: ``\{0,1\}``
      + Default initial value: 1
      + Symbol: ``u^\text{ld}``

**Static Parameters:**

  - ``P^\text{ld,max}`` = `PowerSystems.get_max_active_power(device)`
  - ``Q^\text{ld,max}`` = `PowerSystems.get_max_reactive_power(device)`

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
mdtable(combo_table; latex = false)
```

**Objective:**

Creates an objective function term based on the [`FunctionData` Options](@ref) where the quantity term is defined as ``p^\text{ld}``.

**Expressions:**

  - Subtract``p^\text{ld}`` and ``q^\text{ld}`` terms and to the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref network_formulations)

**Constraints:**

```math
\begin{aligned}
&  p_t^\text{ld} \le u_t^\text{ld} \cdot \text{ActivePowerTimeSeriesParameter}_t, \quad \forall t \in \{1,\dots, T\} \\
&  q_t^\text{re} = \text{pf} \cdot p_t^\text{re}, \quad \forall t \in \{1,\dots, T\}
\end{aligned}
```

on which ``\text{pf} = \sin(\arctan(Q^\text{ld,max}/P^\text{ld,max}))``.

* * *

## `PowerLoadDispatch`

```@docs
PowerLoadDispatch
```

**Variables:**

  - [`ActivePowerVariable`](@ref):
    
      + Bounds: [0.0, ]
      + Default initial value: `PowerSystems.get_active_power(device)`
      + Symbol: ``p^\text{ld}``

  - [`ReactivePowerVariable`](@ref):
    
      + Bounds: [0.0, ]
      + Default initial value: `PowerSystems.get_reactive_power(device)`
      + Symbol: ``q^\text{ld}``

**Static Parameters:**

  - ``P^\text{ld,max}`` = `PowerSystems.get_max_active_power(device)`
  - ``Q^\text{ld,max}`` = `PowerSystems.get_max_reactive_power(device)`

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
mdtable(combo_table; latex = false)
```

**Objective:**

Creates an objective function term based on the [`FunctionData` Options](@ref) where the quantity term is defined as ``p^\text{ld}``.

**Expressions:**

  - Subtract ``p^\text{ld}`` and ``q^\text{ld}`` terms and to the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref network_formulations)

**Constraints:**

```math
\begin{aligned}
&  p_t^\text{ld} \le \text{ActivePowerTimeSeriesParameter}_t, \quad \forall t \in \{1,\dots, T\}\\
&  q_t^\text{ld} = \text{pf} \cdot p_t^\text{ld}, \quad \forall t \in \{1,\dots, T\}\\
\end{aligned}
```

on which ``\text{pf} = \sin(\arctan(Q^\text{ld,max}/P^\text{ld,max}))``.


* * *

## `PowerLoadShift`

```@docs
PowerLoadShift
```

**Variables:**

  - [`ShiftedActivePowerVariable`](@ref):

      + Default initial value: 0.0
      + Symbol: ``p^\text{shift}``

  - [`ReactivePowerVariable`](@ref):
    
      + Default initial value: 0.0
      + Symbol: ``q^\text{ld}``

**Static Parameters:**

  - ``P^\text{max}`` = `PowerSystems.get_max_active_power(device)`
  - ``Q^\text{max}`` = `PowerSystems.get_max_reactive_power(device)`
  - ``T^\text{b}`` = `PowerSystems.get_load_balance_time_horizon(device)`

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(ShiftablePowerLoad, PowerLoadShift)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
)
mdtable(combo_table; latex = false)
```

Only non-negative loads are allowed (i.e., both the requested active power and lower bound active power must be ``\ge 0``).

**Objective:**

Creates an objective function term based on the [`FunctionData` Options](@ref) where the
quantity term is defined as ``max{p_t^\text{shift}, 0}`` (i.e., there is only a cost when
``p_t^\text{shift}`` is negative, reducing total load). 

**Expressions:**

  - Add ``p^\text{shift}`` terms to the active power balance expressions created by the selected [Network Formulations](@ref network_formulations).

**Constraints:**

```math
\begin{aligned}
&  p_t^\text{shift} \ge 0, \quad \forall t \in \{1,\dots, T\} \ \text{ if } \ \text{ActivePowerTimeSeriesParameter}_t<0 \\
&  p_t^\text{shift} + \text{ActivePowerTimeSeriesParameter}_t \ge \max{\{\text{LowerBoundActivePowerTimeSeriesParameter}_t, 0.0\}}, \quad \forall t \in \{1,\dots, T\}\ \text{ if } \ \text{ActivePowerTimeSeriesParameter}_t \ge 0 \\
&  p_t^\text{shift} + \text{ActivePowerTimeSeriesParameter}_t \le \text{UpperBoundActivePowerTimeSeriesParameter}_t, \quad \forall t \in \{1,\dots, T\} \\
& \sum\limits_{t \in \mathcal{T}_k } p_t^\text{shift} = 0 , \quad \forall k \in \{1,\dots, \lceil{T/T^\text{b}}\rceil\}, \ \mathcal{T}_k = \{(k-1)T^\text{b}+1, \ldots, \min{\{kT^\text{b}, N \}} \} \\
&  p_t^\text{shift} \le \begin{cases} 0, &\forall k \in \{1,\dots, \lceil{T/T^\text{b}}\rceil\}, \ t=(k-1)T^{\text{b}}+1 \\[1mm]
\sum\limits_{j<t \in \mathcal{T}_k } p_j^\text{shift}, &\forall k \in \{1,\dots, \lceil{T/T^\text{b}}\rceil\}, \ \forall t \neq (k-1)T^{\text{b}}+1 \in \{1, \ldots, T \}
\end{cases}\\
&  q_t^\text{ld} = \text{pf} \cdot \left( \text{ActivePowerTimeSeriesParameter}_t + p_t^\text{shift} \right), \quad \forall t \in \{1,\dots, T\}
\end{aligned}
```

on which ``\text{pf} = \sin(\arctan(Q^\text{max}/P^\text{max}))``.

## Valid configurations

Valid [`DeviceModel`](@ref)s for subtypes of `ElectricLoad` include the following:

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.generate_device_formulation_combinations()
filter!(x -> x["device_type"] <: ElectricLoad, combos)
combo_table = DataFrame(
    "Valid DeviceModel" =>
        ["`DeviceModel($(c["device_type"]), $(c["formulation"]))`" for c in combos],
    "Device Type" => [
        "[$(c["device_type"])](https://nrel-Sienna.github.io/PowerSystems.jl/stable/model_library/generated_$(c["device_type"])/)"
        for c in combos
    ],
    "Formulation" => ["[$(c["formulation"])](@ref)" for c in combos],
)
mdtable(combo_table; latex = false)
```
