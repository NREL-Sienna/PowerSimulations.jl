# [Simulation](@id running_a_simulation)

!!! tip "Always try to solve the operations problem first before putting together the simulation"
    
    It is not uncommon that when trying to solve a complex simulation the resulting models are infeasible. This situation can be the result of many factors like the input data, the incorrect specification of the initial conditions for models with time dependencies or a poorly specified model. Therefore, it's highly recommended to run and analyze an [Operations Problems](@ref psi_structure) that reflect the problems that will be included in a simulation prior to executing a simulation.

Check out the [Operations Problem Tutorial](@ref op_problem_tutorial)

## Feedforward

The definition of exactly what information is passed using the defined chronologies is accomplished using FeedForwards.

Specifically, a FeedForward is used to define what to do with information being passed with an inter-stage chronology in a Simulation. The most common FeedForward is the `SemiContinuousFeedForward` that affects the semi-continuous range constraints of thermal generators in the economic dispatch problems based on the value of the (already solved) unit-commitment variables.

The creation of a FeedForward requires at least to specify the `component_type` on which the FeedForward will be applied. The `source` variable specify which variable will be taken from the problem solved, for example the commitment variable of the thermal unit in the unit commitment problem. Finally, the `affected_values` specify which variables will be affected in the problem to be solved, for example the next economic dispatch problem.

The following code specify the creation of semi-continuous range constraints on the `ActivePowerVariable` based on the solution of the commitment variable `OnVariable` for all `ThermalStandard` units.

```julia
SemiContinuousFeedforward(;
    component_type = ThermalStandard,
    source = OnVariable,
    affected_values = [ActivePowerVariable],
)
```

## Chronologies

In PowerSimulations, chronologies define where information is flowing. There are two types
of chronologies.

  - inter-stage chronologies: Define how information flows between stages. e.g. day-ahead solutions are used to inform economic dispatch problems
  - intra-stage chronologies: Define how information flows between multiple executions of a single stage. e.g. the dispatch setpoints of the first period of an economic dispatch problem are constrained by the ramping limits from setpoints in the final period of the previous problem.

## Sequencing

In a typical simulation pipeline, we want to connect daily (24-hours) day-ahead unit commitment problems, with multiple economic dispatch problems. Usually, our day-ahead unit commitment problem will have an hourly (1-hour) resolution, while the economic dispatch will have a 5-minute resolution.

Depending on your problem, it is common to use a 2-day look-ahead for unit commitment problems, so in this case, the Day-Ahead problem will have: resolution = Hour(1) with interval = Hour(24) and horizon = Hour(48). In the case of the economic dispatch problem, it is common to use a look-ahead of two hours. Thus, the Real-Time problem will have: resolution = Minute(5), with interval = Minute(5) (we only store the first operating point) and horizon = 24 (24 time steps of 5 minutes are 120 minutes, that is 2 hours).

## Simulation Setup

The following code creates the entire simulation pipeline:

```julia
# We assume that the templates for UC and ED are ready
# sys_da has the resolution of 1 hour:
# with the 24 hours interval and horizon of 48 hours.
# sys_rt has the resolution of 5 minutes:
# with a 5-minute interval and horizon of 2 hours (24 time steps)

# Create the UC Decision Model
decision_model_uc = DecisionModel(
    template_uc,
    sys_da;
    name = "UC",
    optimizer = optimizer_with_attributes(
        Xpress.Optimizer,
        "MIPRELSTOP" => 1e-1,
    ),
)

# Create the ED Decision Model
decision_model_ed = DecisionModel(
    template_ed,
    sys_rt;
    name = "ED",
    optimizer = optimizer_with_attributes(Xpress.Optimizer),
)

# Specify the SimulationModels using a Vector of decision_models: UC, ED
sim_models = SimulationModels(;
    decision_models = [
        decision_model_uc,
        decision_model_ed,
    ],
)

# Create the FeedForwards:
semi_ff = SemiContinuousFeedforward(;
    component_type = ThermalStandard,
    source = OnVariable,
    affected_values = [ActivePowerVariable],
)

# Specify the sequencing:
sim_sequence = SimulationSequence(;
    # Specify the vector of decision models: sim_models
    models = sim_models,
    # Specify a Dict of feedforwards on which the FF applies
    # based on the DecisionModel name, in this case "ED"
    feedforwards = Dict(
        "ED" => [semi_ff],
    ),
    # Specify the chronology, in this case inter-stage
    ini_cond_chronology = InterProblemChronology(),
)

# Construct the simulation:
sim = Simulation(;
    name = "compact_sim",
    steps = 10, # 10 days
    models = sim_models,
    sequence = sim_sequence,
    # Specify the start_time as a DateTime: e.g. DateTime("2020-10-01T00:00:00")
    initial_time = start_time,
    # Specify a temporary folder to avoid storing logs if not needed
    simulation_folder = mktempdir(; cleanup = true),
)

# Build the decision models and simulation setup
build!(sim)

# Execute the simulation using the Optimizer specified in each DecisionModel
execute!(sim; enable_progress_bar = true)
```

Check the [PCM tutorial](@ref pcm_tutorial) for a more detailed tutorial on executing a simulation in a production cost modeling (PCM) environment.
