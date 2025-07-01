# [Simulation](@id running_a_simulation)


## Chronologies

In PowerSimulations, chronologies define where information is flowing. There are two types
of chronologies.

  - inter-stage chronologies: Define how information flows between stages. e.g. day-ahead solutions are used to inform economic dispatch problems
  - intra-stage chronologies: Define how information flows between multiple executions of a single stage. e.g. the dispatch setpoints of the first period of an economic dispatch problem are constrained by the ramping limits from setpoints in the final period of the previous problem.
