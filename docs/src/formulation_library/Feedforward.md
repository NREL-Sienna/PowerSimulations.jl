# [FeedForward Formulations](@id ff_formulations)

In PowerSimulations, chronologies define where information is flowing. There are two types
of chronologies.

- inter-stage chronologies: Define how information flows between stages. e.g. day-ahead solutions are used to inform economic dispatch problems
- intra-stage chronologies: Define how information flows between multiple executions of a single stage. e.g. the dispatch setpoints of the first period of an economic dispatch problem are constrained by the ramping limits from setpoints in the final period of the previous problem.

The definition of exactly what information is passed using the defined chronologies is accomplished using **FeedForwards**.

Specifically, a FeedForward is used to define what to do with information being passed with an inter-stage chronology in a Simulation. The most common FeedForward is the `SemiContinuousFeedForward` that affects the semi-continuous range constraints of thermal generators in the economic dispatch problems based on the value of the (already solved) unit-commitment variables.

The creation of a FeedForward requires at least to specify the `component_type` on which the FeedForward will be applied. The `source` variable specify which variable will be taken from the problem solved, for example the commitment variable of the thermal unit in the unit commitment problem. Finally, the `affected_values` specify which variables will be affected in the problem to be solved, for example the next economic dispatch problem.

### Table of contents

1. [`SemiContinuousFeedforward`](#SemiContinuousFeedForward)
2. [`FixValueFeedforward`](#FixValueFeedforward)


---

## `SemiContinuousFeedforward`

```@docs
SemiContinuousFeedforward
```

**Variables:**

No variables are created

**Parameters:**

- ``\text{on}^\text{th}`` = `OnStatusParameter` obtained from the source variable, typically the commitment variable of the unit commitment problem ``u^\text{th}``.

**Objective:**

No changes to the objective function.

**Expressions:**

Adds ``-\text{on}^\text{th}P^\text{th,max}`` to the `ActivePowerRangeExpressionUB` expression and ``-\text{on}^\text{th}P^\text{th,min}`` to the `ActivePowerRangeExpressionLB` expression.

**Constraints:**

Limits the `ActivePowerRangeExpressionUB` and `ActivePowerRangeExpressionLB` by zero as:

```math
\begin{align*}
&  \text{ActivePowerRangeExpressionUB}_t := p_t^\text{th} - \text{on}_t^\text{th}P^\text{th,max} \le 0, \quad  \forall t\in \{1, \dots, T\}  \\
&  \text{ActivePowerRangeExpressionLB}_t := p_t^\text{th} - \text{on}_t^\text{th}P^\text{th,min} \ge 0, \quad  \forall t\in \{1, \dots, T\} 
\end{align*}
```

Thus, if the commitment parameter is zero, the dispatch is limited to zero, forcing to turn off the generator without introducing binary variables in the economic dispatch problem.

## `FixValueFeedforward`

