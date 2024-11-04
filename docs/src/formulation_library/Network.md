# [Network Formulations](@id network_formulations)

Network formulations are used to describe how the network and buses are handled when constructing constraints. The most common constraint decided by the network formulation is the supply-demand balance constraint.

```@docs
NetworkModel
```

Available Network Models are:

| Formulation             | Description                                                                                                                                                   |
|:----------------------- |:------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CopperPlatePowerModel` | Copper plate connection between all components, i.e. infinite transmission capacity                                                                           |
| `AreaBalancePowerModel` | Network model approximation to represent inter-area flow with each area represented as a single node                                                          |
| `PTDFPowerModel`        | Uses the PTDF factor matrix to compute the fraction of power transferred in the network across the branches                                                   |
| `AreaPTDFPowerModel`    | Uses the PTDF factor matrix to compute the fraction of power transferred in the network across the branches and balances power by Area instead of system-wide |

[`PowerModels.jl`](https://github.com/lanl-ansi/PowerModels.jl) available formulations:

  - Exact non-convex models: `ACPPowerModel`, `ACRPowerModel`, `ACTPowerModel`.
  - Linear approximations: `DCPPowerModel`, `NFAPowerModel`.
  - Quadratic approximations: `DCPLLPowerModel`, `LPACCPowerModel`
  - Quadratic relaxations: `SOCWRPowerModel`, `SOCWRConicPowerModel`, `SOCBFPowerModel`, `SOCBFConicPowerModel`, `QCRMPowerModel`, `QCLSPowerModel`.
  - SDP relaxations: `SDPWRMPowerModel`, `SparseSDPWRMPowerModel`.

All of these formulations are described in the [PowerModels.jl documentation](https://lanl-ansi.github.io/PowerModels.jl/stable/formulation-details/) and will not be described here.

* * *

## `CopperPlatePowerModel`

```@docs
CopperPlatePowerModel
```

**Variables:**

If Slack variables are enabled:

  - [`SystemBalanceSlackUp`](@ref):
    
      + Bounds: [0.0, ]
      + Default initial value: 0.0
      + Default proportional cost: 1e6
      + Symbol: ``p^\text{sl,up}``

  - [`SystemBalanceSlackDown`](@ref):
    
      + Bounds: [0.0, ]
      + Default initial value: 0.0
      + Default proportional cost: 1e6
      + Symbol: ``p^\text{sl,dn}``

**Objective:**

Add a large proportional cost to the objective function if slack variables are used ``+ (p^\text{sl,up} + p^\text{sl,dn}) \cdot 10^6``

**Expressions:**

Adds ``p^\text{sl,up}`` and ``p^\text{sl,dn}`` terms to the respective active power balance expressions `ActivePowerBalance` created by this `CopperPlatePowerModel` network formulation.

**Constraints:**

Adds the `CopperPlateBalanceConstraint` to balance the active power of all components available in the system

```math
\begin{align}
&  \sum_{c \in \text{components}} p_t^c = 0, \quad \forall t \in \{1, \dots, T\}
\end{align}
```

* * *

## `AreaBalancePowerModel`

```@docs
AreaBalancePowerModel
```

**Variables:**
If Slack variables are enabled:

  - [`SystemBalanceSlackUp`](@ref) by area:
    
      + Bounds: [0.0, ]
      + Default initial value: 0.0
      + Default proportional cost: 1e6
      + Symbol: ``p^\text{sl,up}``

  - [`SystemBalanceSlackDown`](@ref) by area:
    
      + Bounds: [0.0, ]
      + Default initial value: 0.0
      + Default proportional cost: 1e6
      + Symbol: ``p^\text{sl,dn}``

**Objective:**

Adds ``p^\text{sl,up}`` and ``p^\text{sl,dn}`` terms to the respective active power balance expressions `ActivePowerBalance` per area.

**Expressions:**

Creates `ActivePowerBalance` expressions for each area that then are used to balance active power for all buses within a single area.

**Constraints:**

Adds the `CopperPlateBalanceConstraint` to balance the active power of all components available in an area.

```math
\begin{align}
&  \sum_{c \in \text{components}_a} p_t^c = 0, \quad \forall a\in \{1,\dots, A\}, t \in \{1, \dots, T\}
\end{align}
```

* * *

## `PTDFPowerModel`

```@docs
PTDFPowerModel
```

**Variables:**

If Slack variables are enabled:

  - [`SystemBalanceSlackUp`](@ref):
    
      + Bounds: [0.0, ]
      + Default initial value: 0.0
      + Default proportional cost: 1e6
      + Symbol: ``p^\text{sl,up}``

  - [`SystemBalanceSlackDown`](@ref):
    
      + Bounds: [0.0, ]
      + Default initial value: 0.0
      + Default proportional cost: 1e6
      + Symbol: ``p^\text{sl,dn}``

**Objective:**

Add a large proportional cost to the objective function if slack variables are used ``+ (p^\text{sl,up} + p^\text{sl,dn}) \cdot 10^6``

**Expressions:**

Adds ``p^\text{sl,up}`` and ``p^\text{sl,dn}`` terms to the respective system-wide active power balance expressions `ActivePowerBalance` created by this `CopperPlatePowerModel` network formulation. In addition, it creates `ActivePowerBalance` expressions for each bus to be used in the calculation of branch flows.

**Constraints:**

Adds the `CopperPlateBalanceConstraint` to balance the active power of all components available in the system

```math
\begin{align}
&  \sum_{c \in \text{components}} p_t^c = 0, \quad \forall t \in \{1, \dots, T\}
\end{align}
```

In addition creates `NodalBalanceActiveConstraint` for HVDC buses balance, if DC components are connected to an HVDC network.

## `AreaPTDFPowerModel`

```@docs
AreaPTDFPowerModel
```

**Variables**

Slack variables are not supported.

**Objective Function**

No changes to the objective function.

**Expressions**

Creates the area-wide and nodal-wide active power balance expressions `ActivePowerBalance` to balance power based on each area independently. The flows across areas are computed based on the PTDF factors of lines connecting areas.

**Constraints:**

Adds the `ActivePowerBalance` constraint to balance the active power of all components available for each area.

```math
\begin{align}
&  \sum_{c \in \text{components}_a} p_t^c = 0, \quad \forall a\in \{1,\dots, A\}, t \in \{1, \dots, T\}
\end{align}
```

This includes the flows of lines based on the PTDF factors.
