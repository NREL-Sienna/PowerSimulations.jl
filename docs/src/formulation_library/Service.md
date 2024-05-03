# [`PowerSystems.Service` Formulations](@id service_formulations)

`Services` (or ancillary services) are models used to ensure that there is necessary support to the power grid from generators to consumers, in order to ensure reliable operation of the system.

The most common application for ancillary services are reserves, i.e., generation (or load) that is not currently being used, but can be quickly made available in case of unexpected changes of grid conditions, for example a sudden loss of load or generation.

A key challenge of adding services to a system, from a mathematical perspective, is specifying which units contribute to the specified requirement of a service, that implies the creation of new variables (such as reserve variables) and modification of constraints.

In this documentation, we first specify the available `Services` in the grid, and what requirements impose in the system, and later we discuss the implication on device formulations for specific units.

## `RangeReserve`

For each service ``s`` of the model type `RangeReserve` the following variables are created:

**Variables**:

- [`ActivePowerReserveVariable`](@ref):
    - Bounds: [0.0, ]
    - Symbol: ``r_{d}`` for ``d`` in contributing devices to the service ``s``
If slacks are enabled:
- [`ReserveRequirementSlack`](@ref):
    - Bounds: [0.0, ]
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

``\mathcal{D}_s`` = `PowerSystems.get_contributing_devices(system, service)`: Set (vector) of all contributing devices to the service ``s`` in the system.

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
