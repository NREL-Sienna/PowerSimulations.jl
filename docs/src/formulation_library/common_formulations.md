# Common Formulations

## `FixedOutput`

```@docs
FixedOutput
```

**Variables**

No variables are created for `DeviceModel(<:DeviceType, FixedOutput)`

**Parameters**

- ``P_t``: power injection (generators) or withdrawal (loads) for the device at time ``t`` (MW) - defaults to use the `max_active_power` time series

**Objective**

No objective terms are created for `DeviceModel(<:DeviceType, FixedOutput)`

**Constraints**

No constraints are created for `DeviceModel(<:DeviceType, FixedOutput)`

---

## `VariableCost` Options

PowerSimulations can represent variable costs using a variety of different methods depending on the data available in each device. The following describes the objective function terms that are populated for each variable cost option.

### Scalar `VariableCost`

`variable_cost <: Float64`: creates a fixed marginal cost term in the objective function

```math
\begin{aligned}
&  C * G_t
\end{aligned}
```

### Polynomial `VariableCost`

`variable_cost <: Tuple{Float64, Float64}`: creates a polynomial cost term in the objective function where

- ``C_g``=`variable_cost[1]`
- ``C_g^\prime``=`variable_cost[2]`

```math
\begin{aligned}
&  C * G_t + C^\prime * G_t^2
\end{aligned}
```

### Piecewise Linear `VariableCost`

`variable_cost <: Vector{Tuple{Float64, Float64}}`: creates a piecewise linear cost term in the objective function 

TODO: Fix this formulation 

```math
\begin{aligned}
&  G_t = \sum_{l \in 1..L}(G_l - G_1) \lambda_l{l,t} & \forall t \in T \\
&  C_t = \sum_{l \in 1..L}(G_t*C_l - G_t*C_1) \lambda_{l,t} & \forall t \in T\\
&  U_g(t) = \sum_{l \in 1..L} \lambda_{l,t} & \forall t \in T 
\end{aligned}
```
