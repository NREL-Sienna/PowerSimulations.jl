# [Piecewise linear cost functions](@id pwl_cost)

The choice for piecewise-linear (PWL) cost representation in  `PowerSimulations.jl` is equivalent to the so-called λ-model from the paper [_The Impacts of Convex Piecewise Linear Cost Formulations on AC Optimal Power Flow_](https://www.sciencedirect.com/science/article/pii/S0378779621001723). The SOS constraints in each model are only implemented if the data for PWL is not convex.

## Special Ordered Set (SOS) Constraints

A special ordered set (SOS) is an ordered set of variables used as an additional way to specify integrality conditions in an optimization model.

- Special Ordered Sets of type 1 (SOS1) are a set of variables, at  most one of which can take a non-zero value, all others being at 0. They most frequently applications is in a a set of variables that are actually binary variables: in other words, we have to choose at most one from a set of possibilities.
- Special Ordered Sets of type 2 (SOS2) are an ordered set of non-negative variables, of which at most two can be non-zero, and if two are non-zero these must be consecutive in their ordering. Special Ordered Sets of type 2 are typically used to model non-linear functions of a variable in a linear model, such as non-convex quadratic functions using PWL functions.

## Standard representation of PWL costs

Piecewise-linear costs are defined by a sequence of points representing the line segments for each generator: ``(P_k^\text{max}, C_k)`` on which we assume ``C_k`` is the cost of generating ``P_k^\text{max}`` power, and ``k \in \{1,\dots, K\}`` are the number of segments each generator cost function has.

### Commitment formulation

 With this the standard representation of PWL costs for a thermal unit commitment is given by:

```math
\begin{align*}
 \min_{\substack{p_{t}, \delta_{k,t}}}
 & \sum_{t \in \mathcal{T}} \left(\sum_{k \in \mathcal{K}} C_{k,t} \delta_{k,t} \right) \Delta t\\
 & \sum_{k \in \mathcal{K}} P_{k}^{\text{max}} \delta_{k,t} = p_{t} & \forall t \in \mathcal{T}\\
 & \sum_{k \in \mathcal{K}} \delta_{k,t} = u_{t} & \forall t \in \mathcal{T}\\
 & P^{\text{min}} u_{t} \leq p_{t} \leq P^{\text{max}} u_{t} & \forall t \in \mathcal{T}\\
 &\left \{\delta_{1,t}, \dots, \delta_{K,t} \right \} \in \text{SOS}_{2} & \forall t \in \mathcal{T}
\end{align*}
```
on which ``\delta_{k,t} \in [0,1]`` is the interpolation variable, ``p`` is the active power of the generator and ``u \in \{0,1\}`` is the commitment variable of the generator. In the case of a PWL convex costs, i.e. increasing slopes, the SOS constraint is omitted.

### Dispatch formulation

```math
\begin{align*}
 \min_{\substack{p_{t}, \delta_{k,t}}}
 & \sum_{t \in \mathcal{T}} \left(\sum_{k \in \mathcal{K}} C_{k,t} \delta_{k,t} \right) \Delta t\\
 & \sum_{k \in \mathcal{K}} P_{k}^{\text{max}} \delta_{k,t} = p_{t} & \forall t \in \mathcal{T}\\
 & \sum_{k \in \mathcal{K}} \delta_{k,t} = \text{on}_{t} & \forall t \in \mathcal{T}\\
 & P^{\text{min}} \text{on}_{t} \leq p_{t} \leq P^{\text{max}} \text{on}_{t} & \forall t \in \mathcal{T}\\
 &\left \{\delta_{i,t}, \dots, \delta_{k,t} \right \} \in \text{SOS}_{2} & \forall t \in \mathcal{T}
\end{align*}
```
on which ``\delta_{k,t} \in [0,1]`` is the interpolation variable, ``p`` is the active power of the generator and ``\text{on} \in \{0,1\}`` is the parameter that decides if the generator is available or not. In the case of a PWL convex costs, i.e. increasing slopes, the SOS constraint is omitted.