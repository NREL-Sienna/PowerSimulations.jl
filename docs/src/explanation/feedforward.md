# [Feedforward](@id feedforward)

The definition of exactly what information is passed using the defined chronologies is accomplished using FeedForwards.

Specifically, a FeedForward is used to define what to do with information being passed with an inter-stage chronology in a Simulation. The most common FeedForward is the `SemiContinuousFeedForward` that affects the semi-continuous range constraints of thermal generators in the economic dispatch problems based on the value of the (already solved) unit-commitment variables.

The creation of a FeedForward requires at least to specify the `component_type` on which the FeedForward will be applied. The `source` variable specify which variable will be taken from the problem solved, for example the commitment variable of the thermal unit in the unit commitment problem. Finally, the `affected_values` specify which variables will be affected in the problem to be solved, for example the next economic dispatch problem.
