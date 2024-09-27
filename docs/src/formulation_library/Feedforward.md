# [FeedForward Formulations](@id ff_formulations)

**FeedForwards** are the mechanism to define how information is shared between models. Specifically, a FeedForward defines what to do with information passed with an inter-stage chronology in a Simulation. The most common FeedForward is the `SemiContinuousFeedForward` that affects the semi-continuous range constraints of thermal generators in the economic dispatch problems based on the value of the (already solved) unit-commitment variables.

The creation of a FeedForward requires at least specifying the `component_type` on which the FeedForward will be applied. The `source` variable specifies which variable will be taken from the problem solved, for example, the commitment variable of the thermal unit in the unit commitment problem. Finally, the `affected_values` specify which variables will be affected in the problem to be solved, for example, the next economic dispatch problem.

### Table of contents

 1. [`SemiContinuousFeedforward`](#SemiContinuousFeedForward)
 2. [`FixValueFeedforward`](#FixValueFeedforward)
 3. [`UpperBoundFeedforward`](#UpperBoundFeedforward)
 4. [`LowerBoundFeedforward`](#LowerBoundFeedforward)

* * *

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

* * *

## `FixValueFeedforward`

```@docs
FixValueFeedforward
```

**Variables:**

No variables are created

**Parameters:**

The parameter `FixValueParameter` is used to match the result obtained from the source variable (from the simulation state).

**Objective:**

No changes to the objective function.

**Expressions:**

No changes on expressions.

**Constraints:**

Set the `VariableType` from the `affected_values` to be equal to the source parameter store in `FixValueParameter`

```math
\begin{align*}
&  \text{AffectedVariable}_t = \text{SourceVariableParameter}_t, \quad \forall t \in \{1,\dots, T\}
\end{align*}
```

* * *

## `UpperBoundFeedforward`

```@docs
UpperBoundFeedforward
```

**Variables:**

If slack variables are enabled:

  - [`UpperBoundFeedForwardSlack`](@ref)
    
      + Bounds: [0.0, ]
      + Default proportional cost: 1e6
      + Symbol: ``p^\text{ff,ubsl}``

**Parameters:**

The parameter `UpperBoundValueParameter` stores the result obtained from the source variable (from the simulation state) that will be used as an upper bound to the affected variable.

**Objective:**

The slack variable is added to the objective function using its large default cost ``+ p^\text{ff,ubsl} \cdot 10^6``

**Expressions:**

No changes on expressions.

**Constraints:**

Set the `VariableType` from the `affected_values` to be lower than the source parameter store in `UpperBoundValueParameter`.

```math
\begin{align*}
&   \text{AffectedVariable}_t - p_t^\text{ff,ubsl} \le \text{SourceVariableParameter}_t, \quad \forall t \in \{1,\dots, T\}
\end{align*}
```

* * *

## `LowerBoundFeedforward`

```@docs
LowerBoundFeedforward
```

**Variables:**

If slack variables are enabled:

  - [`LowerBoundFeedForwardSlack`](@ref)
    
      + Bounds: [0.0, ]
      + Default proportional cost: 1e6
      + Symbol: ``p^\text{ff,lbsl}``

**Parameters:**

The parameter `LowerBoundValueParameter` stores the result obtained from the source variable (from the simulation state) that will be used as a lower bound to the affected variable.

**Objective:**

The slack variable is added to the objective function using its large default cost ``+ p^\text{ff,lbsl} \cdot 10^6``

**Expressions:**

No changes on expressions.

**Constraints:**

Set the `VariableType` from the `affected_values` to be greater than the source parameter store in `LowerBoundValueParameter`.

```math
\begin{align*}
&   \text{AffectedVariable}_t + p_t^\text{ff,lbsl} \ge \text{SourceVariableParameter}_t, \quad \forall t \in \{1,\dots, T\}
\end{align*}
```
