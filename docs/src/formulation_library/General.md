# [Formulations](@id formulation_library)

Modeling formulations are created by dispatching on abstract subtypes of `PowerSimulations.AbstractDeviceFormulation`

## `FixedOutput`

```@docs
FixedOutput
```

**Variables:**

No variables are created for `DeviceModel(<:DeviceType, FixedOutput)`

**Static Parameters:**

- ThermalGen:
  - ``P^\text{th,max}`` = `PowerSystems.get_max_active_power(device)`
  - ``Q^\text{th,max}`` = `PowerSystems.get_max_reactive_power(device)`
- Storage:
  - ``P^\text{st,max}`` = `PowerSystems.get_max_active_power(device)`
  - ``Q^\text{st,max}`` = `PowerSystems.get_max_reactive_power(device)`

**Time Series Parameters:**

```@eval
using PowerSimulations
using HydroPowerSimulations
using PowerSystems
using DataFrames
using Latexify
combo_tables = []
for t in [RenewableGen, ThermalGen, HydroGen, ElectricLoad]
    combos = PowerSimulations.get_default_time_series_names(t, FixedOutput)
    combo_table = DataFrame(
        "Parameter" => map(x -> "[`$x`](@ref)", collect(keys(combos))),
        "Default Time Series Name" => map(x -> "`$x`", collect(values(combos))),
        )
    insertcols!(combo_table, 1, "Device Type" => fill(string(t), length(combos)))
    push!(combo_tables, combo_table)
end
mdtable(vcat(combo_tables...), latex = false)
```

**Objective:**

No objective terms are created for `DeviceModel(<:DeviceType, FixedOutput)`

**Expressions:**

Adds the active and reactive parameters listed for specific device types above to the respective active and reactive power balance expressions created by the selected [Network Formulations](@ref network_formulations).

**Constraints:**

No constraints are created for `DeviceModel(<:DeviceType, FixedOutput)`

---

## `FunctionData` Options

PowerSimulations can represent variable costs using a variety of different methods depending on the data available in each device. The following describes the objective function terms that are populated for each variable cost option.

### `LinearFunctionData`

`variable_cost = LinearFunctionData(c)`: creates a fixed marginal cost term in the objective function

```math
\begin{aligned}
&  \text{min} \sum_{t} c * G_t
\end{aligned}
```

### `QuadraticFunctionData` and `PolynomialFunctionData`

`variable_cost::QuadraticFunctionData` and `variable_cost::PolynomialFunctionData`: create a polynomial cost term in the objective function

```math
\begin{aligned}
&  \text{min} \sum_{t} \sum_{n} C_n * G_t^n
\end{aligned}
```

where

- For `QuadraticFunctionData`:
  - ``C_0`` = `get_constant_term(variable_cost)`
  - ``C_1`` = `get_proportional_term(variable_cost)`
  - ``C_2`` = `get_quadratic_term(variable_cost)`
- For `PolynomialFunctionData`:
  - ``C_n`` = `get_coefficients(variable_cost)[n]`

### `` and `PiecewiseLinearSlopeData`

`variable_cost::PiecewiseLinearData` and `variable_cost::PiecewiseLinearSlopeData`: create a piecewise linear cost term in the objective function

```math
\begin{aligned}
&  \text{min} \sum_{t} f(G_t)
\end{aligned}
```

where

- For `variable_cost::PiecewiseLinearData`, ``f(x)`` is the piecewise linear function obtained by connecting the `(x, y)` points `get_points(variable_cost)` in order.
- For `variable_cost = PiecewiseLinearSlopeData([x0, x1, x2, ...], y0, [s0, s1, s2, ...])`, ``f(x)`` is the piecewise linear function obtained by starting at `(x0, y0)`, drawing a segment at slope `s0` to `x=x1`, drawing a segment at slope `s1` to `x=x2`, etc.

___

## `StorageManagementCost`

Adds an objective function cost term according to:

```math
\begin{aligned}
&  \text{min} \sum_{t} \quad [E^{surplus}_t * C^{penalty} - E^{shortage}_t * C^{value}]
\end{aligned}
```

**Impact of different cost configurations:**

The following table describes all possible configuration of the `StorageManagementCost` with the target constraint in hydro or storage device models. Cases 1(a) & 2(a) will have no impact of the models operations and the target constraint will be rendered useless. In most cases that have no energy target and a non-zero value for ``C^{value}``, if this cost is too high (``C^{value} >> 0``) or too low (``C^{value} <<0``) can result in either the model holding on to stored energy till the end or the model not storing any energy in the device. This is caused by the fact that when energy target is zero, we have ``E_t = - E^{shortage}_t``, and ``- E^{shortage}_t * C^{value}`` in the objective function is replaced by ``E_t * C^{value}``, thus resulting in ``C^{value}`` to be seen as the cost of stored energy.


| Case | Energy Target | Energy Shortage Cost | Energy Value / Energy Surplus cost | Effect |
| ---------- | ------------- | ----------------- | ---------- | ----------------------- |
| Case 1(a) | $\hat{E}=0$ | $C^{penalty}=0$ | $C^{value}=0$ | no change |
| Case 1(b) | $\hat{E}=0$ | $C^{penalty}=0$ | $C^{value}<0$ | penalty for storing energy |
| Case 1(c) | $\hat{E}=0$ | $C^{penalty}>0$ | $C^{value}=0$ | no penalties or incentives applied |
| Case 1(d) | $\hat{E}=0$ | $C^{penalty}=0$ | $C^{value}>0$ | incentive for storing energy |
| Case 1(e) | $\hat{E}=0$ | $C^{penalty}>0$ | $C^{value}<0$ | penalty for storing energy |
| Case 1(f) | $\hat{E}=0$ | $C^{penalty}>0$ | $C^{value}>0$ | incentive for storing energy |
| Case 2(a) | $\hat{E}>0$ | $C^{penalty}=0$ | $C^{value}=0$ | no change |
| Case 2(b) | $\hat{E}>0$ | $C^{penalty}=0$ | $C^{value}<0$ | penalty on energy storage in excess of target |
| Case 2(c) | $\hat{E}>0$ | $C^{penalty}>0$ | $C^{value}=0$ | penalty on energy storage short of target |
| Case 2(d) | $\hat{E}>0$ | $C^{penalty}=0$ | $C^{value}>0$ | incentive on excess energy |
| Case 2(e) | $\hat{E}>0$ | $C^{penalty}>0$ | $C^{value}<0$ | penalty on both excess/shortage of energy |
| Case 2(f) | $\hat{E}>0$ | $C^{penalty}>0$ | $C^{value}>0$ | penalty for shortage, incentive for excess energy |
