# [Simulation](@id running_a_simulation)

!!! tip "Always try to solve the operations problem first before putting together the simulation"
    It is not uncommon that when trying to solve a complex simulation the resulting models are infeasible. This situation can be the result of many factors like the input data, the incorrect specification of the initial conditions for models with time dependencies or a poorly specified model. Therefore, it's highly recommended to run and analyze an [Operations Problems](@ref psi_structure) that reflect the problems that will be included in a simulation prior to executing a simulation.

Check out the [Operations Problem Tutorial](@ref op_problem_tutorial)

## Feedforward

TODO

## Sequencing

In a typical simulation pipeline, we want to connect daily (24-hours) day-ahead unit commitment problems, with multiple economic dispatch problems. Usually, our day-ahead unit commitment problem will have an hourly (1-hour) resolution, while the economic dispatch will have a 5-minute resolution.

Depending on your problem, it is common to use a 2-day look-ahead for unit commitment problems, so in this case, the Day-Ahead problem will have: resolution = Hour(1) with interval = Hour(24) and horizon = Hour(48). In the case of the economic dispatch problem, it is common to use a look-ahead of two hours. Thus, the Real-Time problem will have: resolution = Minute(5), with interval = Minute(5) (we only store the first operating point) and horizon = Hour(24) (24 time steps of 5 minutes are 120 minutes, that is 2 hours).
