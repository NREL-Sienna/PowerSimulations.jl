# [Formulations Introduction](@id formulation_intro)

PowerSimulations.jl enables modularity in its formulations by assigning a [`DeviceModel`](@ref) to each `PowerSystems.jl` component type existing in a defined system.

`PowerSimulations.jl` has a multiple `AbstractDeviceFormulation` subtypes that can be applied to different `PowerSystems.jl` device types, each dispatching to different methods for populating the optimization problem **variables**, **objective function**, **expressions** and **constraints**.

## Example Formulation

For example a typical optimization problem in a [`DecisionModel`](@ref) in `PowerSimulations.jl` with three [`DeviceModel`](@ref) has the abstract form of:

```math
\begin{align*}
    &\min_{\boldsymbol{x}}~ \text{Objective\_DeviceModelA} + \text{Objective\_DeviceModelB} + \text{Objective\_DeviceModelC} \\
    & ~~\text{s.t.} \\
    & \hspace{0.9cm} \text{Constraints\_NetworkModel} \\
    & \hspace{0.9cm} \text{Constraints\_DeviceModelA} \\
    & \hspace{0.9cm} \text{Constraints\_DeviceModelB} \\
    & \hspace{0.9cm} \text{Constraints\_DeviceModelC} 
\end{align*}
```

Suppose this is a system with the following characteristics:

  - Horizon: 48 hours
  - Interval: 24 hours
  - Resolution: 1 hour
  - Three Buses: 1, 2 and 3
  - One `ThermalStandard` (device A) unit at bus 1
  - One `RenewableDispatch` (device B) unit at bus 2
  - One `PowerLoad` (device C) at bus 3
  - Three `Line` that connects all the buses

Now, we assign the following [`DeviceModel`](@ref) to each `PowerSystems.jl` with:

| Type                | Formulation             |
|:------------------- |:----------------------- |
| Network             | `CopperPlatePowerModel` |
| `ThermalStandard`   | `ThermalDispatchNoMin`  |
| `RenewableDispatch` | `RenewableFullDispatch` |
| `PowerLoad`         | `StaticPowerLoad`       |

Note that we did not assign any [`DeviceModel`](@ref) to `Line` since the `CopperPlatePowerModel` used for the network assumes that everything is lumped in the same node (like a copper plate with infinite capacity), and hence there are no flows between buses that branches can limit.

Each [`DeviceModel`](@ref) formulation is described in specific in their respective page, but the overall optimization problem will end-up as:

```math
\begin{align*}
    &\min_{\boldsymbol{p}^\text{th}, \boldsymbol{p}^\text{re}}~ \sum_{t=1}^{48} C^\text{th} p_t^\text{th} - C^\text{re} p_t^\text{re} \\
    & ~~\text{s.t.} \\
    & \hspace{0.9cm} p_t^\text{th} + p_t^\text{re} = P_t^\text{load}, \quad \forall t \in {1,\dots, 48} \\
    & \hspace{0.9cm} 0 \le p_t^\text{th} \le P^\text{th,max} \\
    & \hspace{0.9cm} 0 \le p_t^\text{re} \le \text{ActivePowerTimeSeriesParameter}_t 
\end{align*}
```

Note that the `StaticPowerLoad` does not impose any cost to the objective function or constraint but adds its power demand to the supply-balance demand of the `CopperPlatePowerModel` used. Since we are using the `ThermalDispatchNoMin` formulation for the thermal generation, the lower bound for the power is 0, instead of ``P^\text{th,min}``. In addition, we are assuming a linear cost ``C^\text{th}``. Finally, the `RenewableFullDispatch` formulation allows the dispatch of the renewable unit between 0 and its maximum injection time series ``p_t^\text{re,param}``.

# Nomenclature

In the formulations described in the other pages, the nomenclature is as follows:

  - Lowercase letters are used for variables, e.g., ``p`` for power.
  - Uppercase letters are used for parameters, e.g., ``C`` for costs.
  - Subscripts are used for indexing, e.g., ``(\cdot)_t`` for indexing at time ``t``.
  - Superscripts are used for descriptions, e.g., ``(\cdot)^\text{th}`` to describe a thermal (th) variable/parameter.
  - Bold letters are used for vectors, e.g., ``\boldsymbol{p} = \{p\}_{1,\dots,24}``.
