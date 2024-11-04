# `PowerSystems.RenewableGen` Formulations

Renewable generation formulations define the optimization models that describe renewable units mathematical model in different operational settings, such as economic dispatch and unit commitment.

!!! note
    
    The use of reactive power variables and constraints will depend on the network model used, i.e., whether it uses (or does not use) reactive power. If the network model is purely active power-based, reactive power variables and related constraints are not created.

!!! note
    
    Reserve variables for services are not included in the formulation, albeit their inclusion change the variables, expressions, constraints and objective functions created. A detailed description of the implications in the optimization models is described in the [Service formulation](@ref service_formulations) section.

### Table of contents

 1. [`RenewableFullDispatch`](#RenewableFullDispatch)
 2. [`RenewableConstantPowerFactor`](#RenewableConstantPowerFactor)
 3. [Valid configurations](#Valid-configurations)

* * *

## `RenewableFullDispatch`

```@docs
RenewableFullDispatch
```

**Variables:**

  - [`ActivePowerVariable`](@ref):
    
      + Bounds: [0.0, ]
      + Symbol: ``p^\text{re}``

  - [`ReactivePowerVariable`](@ref):
    
      + Bounds: [0.0, ]
      + Symbol: ``q^\text{re}``

**Static Parameters:**

  - ``P^\text{re,min}`` = `PowerSystems.get_active_power_limits(device).min`
  - ``Q^\text{re,min}`` = `PowerSystems.get_reactive_power_limits(device).min`
  - ``Q^\text{re,max}`` = `PowerSystems.get_reactive_power_limits(device).max`

**Time Series Parameters:**

Uses the `max_active_power` timeseries parameter to limit the available active power at each time-step.

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
mdtable(combo_table; latex = false)
```

**Objective:**

Creates an objective function term based on the [`FunctionData` Options](@ref) where the quantity term is defined as ``- p^\text{re}`` to incentivize generation from `RenewableGen` devices.

**Expressions:**

Adds ``p^\text{re}`` and ``q^\text{re}`` terms to the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref network_formulations).

**Constraints:**

```math
\begin{aligned}
&  P^\text{re,min} \le p_t^\text{re} \le \text{ActivePowerTimeSeriesParameter}_t, \quad \forall t \in \{1,\dots, T\} \\
&  Q^\text{re,min} \le q_t^\text{re} \le Q^\text{re,max}, \quad \forall t \in \{1,\dots, T\}
\end{aligned}
```

* * *

## `RenewableConstantPowerFactor`

```@docs
RenewableConstantPowerFactor
```

**Variables:**

  - [`ActivePowerVariable`](@ref):
    
      + Bounds: [0.0, ]
      + Default initial value: `PowerSystems.get_active_power(device)`
      + Symbol: ``p^\text{re}``

  - [`ReactivePowerVariable`](@ref):
    
      + Bounds: [0.0, ]
      + Default initial value: `PowerSystems.get_reactive_power(device)`
      + Symbol: ``q^\text{re}``

**Static Parameters:**

  - ``P^\text{re,min}`` = `PowerSystems.get_active_power_limits(device).min`
  - ``Q^\text{re,min}`` = `PowerSystems.get_reactive_power_limits(device).min`
  - ``Q^\text{re,max}`` = `PowerSystems.get_reactive_power_limits(device).max`
  - ``\text{pf}`` = `PowerSystems.get_power_factor(device)`

**Time Series Parameters:**

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(
    RenewableGen,
    RenewableConstantPowerFactor,
)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
)
mdtable(combo_table; latex = false)
```

**Objective:**

Creates an objective function term based on the [`FunctionData` Options](@ref) where the quantity term is defined as ``- p_t^\text{re}`` to incentivize generation from `RenewableGen` devices.

**Expressions:**

Adds ``p^\text{re}`` and ``q^\text{re}`` terms to the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref network_formulations)

**Constraints:**

```math
\begin{aligned}
&  P^\text{re,min} \le p_t^\text{re} \le \text{ActivePowerTimeSeriesParameter}_t, \quad \forall t \in \{1,\dots, T\} \\
&  q_t^\text{re} = \text{pf} \cdot p_t^\text{re}, \quad \forall t \in \{1,\dots, T\}
\end{aligned}
```

* * *

## Valid configurations

Valid `DeviceModel`s for subtypes of `RenewableGen` include the following:

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.generate_device_formulation_combinations()
filter!(x -> x["device_type"] <: RenewableGen, combos)
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
