# [`PowerSystems.Service` Formulations](@id service_formulations)

`Services` (or ancillary services) are models used to ensure that there is necessary support to the power grid from generators to consumers, in order to ensure reliable operation of the system.

The most common application for ancillary services are reserves, i.e., generation (or load) that is not currently being used, but can be quickly made available in case of unexpected changes of grid conditions, for example a sudden loss of load or generation.

A key challenge of adding services to a system, from a mathematical perspective, is specifying which units contribute to the specified requirement of a service, that implies the creation of new variables (such as reserve variables) and modification of constraints.

In this documentation, we first specify the available `Services` in the grid, and what requirements impose in the system, and later we discuss the implication on device formulations for specific units.

### Table of contents

1. [`RangeReserve`](#RangeReserve)
2. [`StepwiseCostReserve`](#StepwiseCostReserve)
3. [`GroupReserve`](#GroupReserve)
4. [`RampReserve`](#RampReserve)
5. [`NonSpinningReserve`](#NonSpinningReserve)
6. [`ConstantMaxInterfaceFlow`](#ConstantMaxInterfaceFlow)
7. [Changes on Expressions](#Changes-on-Expressions-due-to-Service-models)

---

## `RangeReserve`

```@docs
RangeReserve
```

For each service ``s`` of the model type `RangeReserve` the following variables are created:

**Variables**:

- [`ActivePowerReserveVariable`](@ref):
    - Bounds: [0.0, ]
    - Default proportional cost: ``1.0 / \text{SystemBasePower}``
    - Symbol: ``r_{d}`` for ``d`` in contributing devices to the service ``s``
If slacks are enabled:
- [`ReserveRequirementSlack`](@ref):
    - Bounds: [0.0, ]
    - Default proportional cost: 1e5
    - Symbol: ``r^\text{sl}``

Depending on the `PowerSystems.jl` type associated to the `RangeReserve` formulation model, the parameters are:

**Static Parameters**

- ``\text{PF}`` = `PowerSystems.get_max_participation_factor(service)`

For a `StaticReserve` `PowerSystems` type:
- ``\text{Req}`` = `PowerSystems.get_requirement(service)`

**Time Series Parameters** 

For a `VariableReserve` `PowerSystems` type:
```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(VariableReserve, RangeReserve)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Relevant Methods:**

- ``\mathcal{D}_s`` = `PowerSystems.get_contributing_devices(system, service)`: Set (vector) of all contributing devices to the service ``s`` in the system.

**Objective:**

Add a large proportional cost to the objective function if slack variables are used ``+ r^\text{sl} \cdot 10^5``. In addition adds the default cost for `ActivePowerReserveVariables` as a proportional cost.

**Expressions:**

Adds the `ActivePowerReserveVariable` for upper/lower bound expressions of contributing devices.

For `ReserveUp` types, the variable is added to `ActivePowerRangeExpressionUB`, such that this expression considers both the `ActivePowerVariable` and its reserve variable. Similarly, For `ReserveDown` types, the variable is added to `ActivePowerRangeExpressionLB`, such that this expression considers both the `ActivePowerVariable` and its reserve variable


*Example*: for a thermal unit ``d`` contributing to two different `ReserveUp` ``s_1, s_2`` services (e.g. Reg-Up and Spin):
```math
\text{ActivePowerRangeExpressionUB}_{t} = p_t^\text{th} + r_{s_1,t} + r_{s_2, t} \le P^\text{th,max}
```
similarly if ``s_3`` is a `ReserveDown` service (e.g. Reg-Down):
```math
\text{ActivePowerRangeExpressionLB}_{t} = p_t^\text{th} - r_{s_3,t}  \ge P^\text{th,min}
```

**Constraints:** 

A RangeReserve implements two fundamental constraints. The first is that the sum of all reserves of contributing devices must be larger than the `RangeReserve` requirement. Thus, for a service ``s``:

```math
\sum_{d\in\mathcal{D}_s} r_{d,t} + r_t^\text{sl} \ge \text{Req},\quad \forall t\in \{1,\dots, T\} \quad \text{(for a StaticReserve)} \\
\sum_{d\in\mathcal{D}_s} r_{d,t} + r_t^\text{sl} \ge \text{RequirementTimeSeriesParameter}_{t},\quad \forall t\in \{1,\dots, T\} \quad \text{(for a VariableReserve)}
```

In addition, there is a restriction on how much each contributing device ``d`` can contribute to the requirement, based on the max participation factor allowed.

```math
r_{d,t} \le \text{Req} \cdot \text{PF} ,\quad \forall d\in \mathcal{D}_s, \forall t\in \{1,\dots, T\} \quad \text{(for a StaticReserve)} \\
r_{d,t} \le \text{RequirementTimeSeriesParameter}_{t} \cdot \text{PF}\quad  \forall d\in \mathcal{D}_s, \forall t\in \{1,\dots, T\}, \quad \text{(for a VariableReserve)}
```

---

## `StepwiseCostReserve`

Service must be used with `ReserveDemandCurve` `PowerSystems.jl` type. This service model is used to model ORDC (Operating Reserve Demand Curve) in ERCOT.

```@docs
StepwiseCostReserve
```

For each service ``s`` of the model type `ReserveDemandCurve` the following variables are created:

**Variables**:

- [`ActivePowerReserveVariable`](@ref):
    - Bounds: [0.0, ]
    - Symbol: ``r_{d}`` for ``d`` in contributing devices to the service ``s``
- [`ServiceRequirementVariable`](@ref):
    - Bounds: [0.0, ]
    - Symbol: ``\text{req}``

**Time Series Parameters** 

For a `ReserveDemandCurve` `PowerSystems` type:
```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(ReserveDemandCurve, StepwiseCostReserve)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Relevant Methods:**

- ``\mathcal{D}_s`` = `PowerSystems.get_contributing_devices(system, service)`: Set (vector) of all contributing devices to the service ``s`` in the system.

**Objective:**

The `ServiceRequirementVariable` is added as a piecewise linear cost based on the decreasing offers listed in the `variable_cost` time series. These decreasing cost represent the scarcity prices of not having sufficient reserves. For example, if the variable ``\text{req} = 0``, then a really high cost is paid for not having enough reserves, and if ``\text{req}`` is larger, then a lower cost (or even zero) is paid.

**Expressions:**

Adds the `ActivePowerReserveVariable` for upper/lower bound expressions of contributing devices.

For `ReserveUp` types, the variable is added to `ActivePowerRangeExpressionUB`, such that this expression considers both the `ActivePowerVariable` and its reserve variable. Similarly, For `ReserveDown` types, the variable is added to `ActivePowerRangeExpressionLB`, such that this expression considers both the `ActivePowerVariable` and its reserve variable


*Example*: for a thermal unit ``d`` contributing to two different `ReserveUp` ``s_1, s_2`` services (e.g. Reg-Up and Spin):
```math
\text{ActivePowerRangeExpressionUB}_{t} = p_t^\text{th} + r_{s_1,t} + r_{s_2, t} \le P^\text{th,max}
```
similarly if ``s_3`` is a `ReserveDown` service (e.g. Reg-Down):
```math
\text{ActivePowerRangeExpressionLB}_{t} = p_t^\text{th} - r_{s_3,t}  \ge P^\text{th,min}
```

**Constraints:** 

A `StepwiseCostReserve` implements a single constraint, such that the sum of all reserves of contributing devices must be larger than the `ServiceRequirementVariable` variable. Thus, for a service ``s``:

```math
\sum_{d\in\mathcal{D}_s} r_{d,t}  \ge \text{req}_t,\quad \forall t\in \{1,\dots, T\}  
```

## `GroupReserve`

Service must be used with `StaticReserveGroup` `PowerSystems.jl` type. This service model is used to model an aggregation of services.

```@docs
GroupReserve
```

For each service ``s`` of the model type `GroupReserve` the following variables are created:

**Variables**:

No variables are created, but the services associated with the `GroupReserve` must have created variables.

**Static Parameters**

- ``\text{Req}`` = `PowerSystems.get_requirement(service)`

**Relevant Methods:**

- ``\mathcal{S}_s`` = `PowerSystems.get_contributing_services(system, service)`: Set (vector) of all contributing services to the group service ``s`` in the system.
- ``\mathcal{D}_{s_i}`` = `PowerSystems.get_contributing_devices(system, service_aux)`: Set (vector) of all contributing devices to the service ``s_i`` in the system.

**Objective:**

Does not modify the objective function, besides the changes to the objective function due to the other services associated to the group service.

**Expressions:**

No changes, besides the changes to the expressions due to the other services associated to the group service.

**Constraints:**

A GroupReserve implements that the sum of all reserves of contributing devices, of all contributing services, must be larger than the `GroupReserve` requirement. Thus, for a `GroupReserve` service ``s``:

```math
\sum_{d\in\mathcal{D}_{s_i}} \sum_{i \in \mathcal{S}_s} r_{d,t} \ge \text{Req},\quad \forall t\in \{1,\dots, T\} 
```

---

## `RampReserve`

```@docs
RampReserve
```

For each service ``s`` of the model type `RampReserve` the following variables are created:

**Variables**:

- [`ActivePowerReserveVariable`](@ref):
    - Bounds: [0.0, ]
    - Default proportional cost: ``1.0 / \text{SystemBasePower}``
    - Symbol: ``r_{d}`` for ``d`` in contributing devices to the service ``s``
If slacks are enabled:
- [`ReserveRequirementSlack`](@ref):
    - Bounds: [0.0, ]
    - Default proportional cost: 1e5
    - Symbol: ``r^\text{sl}``

`RampReserve` only accepts `VariableReserve` `PowerSystems.jl` type. With that, the parameters are:

**Static Parameters**

- ``\text{TF}`` = `PowerSystems.get_time_frame(service)`
- ``R^\text{th,up}`` = `PowerSystems.get_ramp_limits(device).up` for thermal contributing devices
- ``R^\text{th,dn}`` = `PowerSystems.get_ramp_limits(device).down` for thermal contributing devices


**Time Series Parameters** 

For a `VariableReserve` `PowerSystems` type:
```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(VariableReserve, RampReserve)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Relevant Methods:**

- ``\mathcal{D}_s`` = `PowerSystems.get_contributing_devices(system, service)`: Set (vector) of all contributing devices to the service ``s`` in the system.

**Objective:**

Add a large proportional cost to the objective function if slack variables are used ``+ r^\text{sl} \cdot 10^5``. In addition adds the default cost for `ActivePowerReserveVariables` as a proportional cost.

**Expressions:**

Adds the `ActivePowerReserveVariable` for upper/lower bound expressions of contributing devices.

For `ReserveUp` types, the variable is added to `ActivePowerRangeExpressionUB`, such that this expression considers both the `ActivePowerVariable` and its reserve variable. Similarly, For `ReserveDown` types, the variable is added to `ActivePowerRangeExpressionLB`, such that this expression considers both the `ActivePowerVariable` and its reserve variable


*Example*: for a thermal unit ``d`` contributing to two different `ReserveUp` ``s_1, s_2`` services (e.g. Reg-Up and Spin):
```math
\text{ActivePowerRangeExpressionUB}_{t} = p_t^\text{th} + r_{s_1,t} + r_{s_2, t} \le P^\text{th,max}
```
similarly if ``s_3`` is a `ReserveDown` service (e.g. Reg-Down):
```math
\text{ActivePowerRangeExpressionLB}_{t} = p_t^\text{th} - r_{s_3,t}  \ge P^\text{th,min}
```

**Constraints:** 

A RampReserve implements three fundamental constraints. The first is that the sum of all reserves of contributing devices must be larger than the `RampReserve` requirement. Thus, for a service ``s``:

```math
\sum_{d\in\mathcal{D}_s} r_{d,t} + r_t^\text{sl} \ge \text{RequirementTimeSeriesParameter}_{t},\quad \forall t\in \{1,\dots, T\}
```

Finally, there is a restriction based on the ramp limits of the contributing devices:

```math
r_{d,t} \le R^\text{th,up} \cdot \text{TF}\quad  \forall d\in \mathcal{D}_s, \forall t\in \{1,\dots, T\}, \quad \text{(for ReserveUp)} \\
r_{d,t} \le R^\text{th,dn} \cdot \text{TF}\quad  \forall d\in \mathcal{D}_s, \forall t\in \{1,\dots, T\}, \quad \text{(for ReserveDown)}
```

---

## `NonSpinningReserve`

```@docs
NonSpinningReserve
```

For each service ``s`` of the model type `NonSpinningReserve`, the following variables are created:

**Variables**:

- [`ActivePowerReserveVariable`](@ref):
    - Bounds: [0.0, ]
    - Default proportional cost: ``1.0 / \text{SystemBasePower}``
    - Symbol: ``r_{d}`` for ``d`` in contributing devices to the service ``s``
If slacks are enabled:
- [`ReserveRequirementSlack`](@ref):
    - Bounds: [0.0, ]
    - Default proportional cost: 1e5
    - Symbol: ``r^\text{sl}``

`NonSpinningReserve` only accepts `VariableReserve` `PowerSystems.jl` type. With that, the parameters are:

**Static Parameters**

- ``\text{PF}`` = `PowerSystems.get_max_participation_factor(service)`
- ``\text{TF}`` = `PowerSystems.get_time_frame(service)`
- ``P^\text{th,min}`` = `PowerSystems.get_active_power_limits(device).min` for thermal contributing devices
- ``T^\text{st,up}`` = `PowerSystems.get_time_limits(d).up` for thermal contributing devices
- ``R^\text{th,up}`` = `PowerSystems.get_ramp_limits(device).down` for thermal contributing devices

Other parameters:

- ``\Delta T``: Resolution of the problem in minutes.

**Time Series Parameters** 

For a `VariableReserve` `PowerSystems` type:
```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.get_default_time_series_names(VariableReserve, NonSpinningReserve)
combo_table = DataFrame(
    "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
    "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
    )
mdtable(combo_table, latex = false)
```

**Relevant Methods:**

- ``\mathcal{D}_s`` = `PowerSystems.get_contributing_devices(system, service)`: Set (vector) of all contributing devices to the service ``s`` in the system.

**Objective:**

Add a large proportional cost to the objective function if slack variables are used ``+ r^\text{sl} \cdot 10^5``. In addition adds the default cost for `ActivePowerReserveVariables` as a proportional cost.

**Expressions:**

Adds the `ActivePowerReserveVariable` for upper/lower bound expressions of contributing devices.

For `ReserveUp` types, the variable is added to `ActivePowerRangeExpressionUB`, such that this expression considers both the `ActivePowerVariable` and its reserve variable. Similarly, For `ReserveDown` types, the variable is added to `ActivePowerRangeExpressionLB`, such that this expression considers both the `ActivePowerVariable` and its reserve variable


*Example*: for a thermal unit ``d`` contributing to two different `ReserveUp` ``s_1, s_2`` services (e.g. Reg-Up and Spin):
```math
\text{ActivePowerRangeExpressionUB}_{t} = p_t^\text{th} + r_{s_1,t} + r_{s_2, t} \le P^\text{th,max}
```
similarly if ``s_3`` is a `ReserveDown` service (e.g. Reg-Down):
```math
\text{ActivePowerRangeExpressionLB}_{t} = p_t^\text{th} - r_{s_3,t}  \ge P^\text{th,min}
```

**Constraints:** 

A NonSpinningReserve implements three fundamental constraints. The first is that the sum of all reserves of contributing devices must be larger than the `NonSpinningReserve` requirement. Thus, for a service ``s``:

```math
\sum_{d\in\mathcal{D}_s} r_{d,t} + r_t^\text{sl} \ge \text{RequirementTimeSeriesParameter}_{t},\quad \forall t\in \{1,\dots, T\}
```

In addition, there is a restriction on how much each contributing device ``d`` can contribute to the requirement, based on the max participation factor allowed.

```math
r_{d,t} \le \text{RequirementTimeSeriesParameter}_{t} \cdot \text{PF}\quad  \forall d\in \mathcal{D}_s, \forall t\in \{1,\dots, T\},
```

Finally, there is a restriction based on the reserve response time for the non-spinning reserve if the unit is off. To do so, compute ``R^\text{limit}_d`` as the reserve response limit as:
```math
R^\text{limit}_d = \begin{cases}
0 & \text{ if TF } \le T^\text{st,up}_d \\
P^\text{th,min}_d +  (\text{TF}_s - T^\text{st,up}_d) \cdot R^\text{th,up}_d \Delta T \cdot R^\text{th,up}_d & \text{ if TF } > T^\text{st,up}_d
\end{cases}, \quad \forall d\in \mathcal{D}_s
```

Then, the constraint depends on the commitment variable ``u_t^\text{th}`` as:

```math
r_{d,t} \le (1 - u_{d,t}^\text{th}) \cdot R^\text{limit}_d, \quad \forall d \in \mathcal{D}_s, \forall t \in \{1,\dots, T\}
```

---

## `ConstantMaxInterfaceFlow`

This Service model only accepts the `PowerSystems.jl` `TransmissionInterface` type to properly function. It is used to model a collection of branches that make up an interface or corridor with a maximum transfer of power.

```@docs
ConstantMaxInterfaceFlow
```

**Variables**

If slacks are used:
- [`InterfaceFlowSlackUp`](@ref):
    - Bounds: [0.0, ]
    - Symbol: ``f^\text{sl,up}``
- [`InterfaceFlowSlackDown`](@ref):
    - Bounds: [0.0, ]
    - Symbol: ``f^\text{sl,dn}``

**Static Parameters**

- ``F^\text{max}`` = `PowerSystems.get_active_power_flow_limits(service).max`
- ``F^\text{min}`` = `PowerSystems.get_active_power_flow_limits(service).min`
- ``C^\text{flow}`` = `PowerSystems.get_violation_penalty(service)`
- ``\mathcal{M}_s`` = `PowerSystems.get_direction_mapping(service)`. Dictionary of contributing branches with its specified direction (``\text{Dir}_d = 1`` or ``\text{Dir}_d = -1``) with respect to the interface.

**Relevant Methods**

- ``\mathcal{D}_s`` = `PowerSystems.get_contributing_devices(system, service)`: Set (vector) of all contributing branches to the service ``s`` in the system.

**Objective:**

Add the violation penalty proportional cost to the objective function if slack variables are used ``+ (f^\text{sl,up} + f^\text{sl,dn}) \cdot C^\text{flow}``.

**Expressions:**

Creates the expression `InterfaceTotalFlow` to keep track of all `FlowActivePowerVariable` of contributing branches to the transmission interface.

**Constraints:**

It adds the constraint to limit the `InterfaceTotalFlow` by the specified bounds of the service ``s``:

```math
F^\text{min} \le f^\text{sl,up}_t - f^\text{sl,dn}_t + \sum_{d\in\mathcal{D}_s} \text{Dir}_d f_{d,t} \le F^\text{max}, \quad \forall t \in \{1,\dots,T\}
```

## Changes on Expressions due to Service models

It is important to note that by adding a service to a Optimization Problem, variables for each contributing device must be created. For example, for every contributing generator ``d \in \mathcal{D}`` that is participating in services ``s_1,s_2,s_3``, it is required to create three set of `ActivePowerReserveVariable` variables:

```math
r_{s_1,d,t},~ r_{s_2,d,t},~ r_{s_3,d,t},\quad \forall d \in \mathcal{D}, \forall t \in \{1,\dots, T\}
```

### Changes on UpperBound (UB) and LowerBound (LB) limits

Each contributing generator ``d`` has active power limits that the reserve variables affect. In simple terms, the limits are implemented using expressions `ActivePowerRangeExpressionUB` and `ActivePowerRangeExpressionLB` as:

```math
\text{ActivePowerRangeExpressionUB}_t \le P^\text{max} \\
\text{ActivePowerRangeExpressionLB}_t \ge P^\text{min}
```
`ReserveUp` type variables contribute to the upper bound expression, while `ReserveDown` variables contribute to the lower bound expressions. So if ``s_1,s_2`` are `ReserveUp` services, and ``s_3`` is a `ReserveDown` service, then for a thermal generator ``d`` using a `ThermalStandardDispatch`:

```math
\begin{align*}
& p_{d,t}^\text{th} + r_{s_1,d,t} + r_{s_2,d,t} \le P^\text{th,max},\quad \forall d\in \mathcal{D}^\text{th}, \forall t \in \{1,\dots,T\} \\
& p_{d,t}^\text{th} - r_{s_3,d,t} \ge P^\text{th,min},\quad \forall d\in \mathcal{D}^\text{th}, \forall t \in \{1,\dots,T\}
\end{align*}
```

while for a renewable generator ``d`` using a `RenewableFullDispatch`:

```math
\begin{align*}
& p_{d,t}^\text{re} + r_{s_1,d,t} + r_{s_2,d,t} \le \text{ActivePowerTimeSeriesParameter}_t,\quad \forall d\in \mathcal{D}^\text{re}, \forall t \in \{1,\dots,T\}\\
& p_{d,t}^\text{re} - r_{s_3,d,t} \ge 0,\quad \forall d\in \mathcal{D}^\text{re}, \forall t \in \{1,\dots,T\}
\end{align*}
```

### Changes in Ramp limits

For the case of Ramp Limits (of formulation that model these limits), the reserve variables only affect the current time, and not the previous time. Then, for the same example as before:
```math
\begin{align*}
& p_{d,t}^\text{th} + r_{s_1,d,t} + r_{s_2,d,t} - p_{d,t-1}^\text{th}\le R^\text{th,up},\quad \forall d\in \mathcal{D}^\text{th}, \forall t \in \{1,\dots,T\}\\
& p_{d,t}^\text{th} - r_{s_3,d,t} - p_{d,t-1}^\text{th}  \ge -R^\text{th,dn},\quad \forall d\in \mathcal{D}^\text{th}, \forall t \in \{1,\dots,T\}
\end{align*}
```
