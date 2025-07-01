# Temporary Section for Unsorted Documentation Content

This file collects content from the old documentation that is not currently included in the restructured Diátaxis layout. It is meant for tracking purposes only and will not be included in the final updated documentation.

## From: Welcome Page

### How the documentation is structured

`PowerSimulations.jl` documentation and code are organized according to the needs of different users depending on their skillset and requirements. In broad terms there are three categories:

  - **Modeler**: Users that want to solve an operations problem or run a simulation using the existing models in `PowerSimulations.jl`. For instance, answer questions about the change in operation costs in future fuel mixes. Check the formulations library page to choose a modeling strategy that fits your needs.

  - **Model Developer**: Users that want to develop custom models and workflows for the simulation of a power system operation. For instance, study the impacts of an stochastic optimization problem over a deterministic.
  - **Code Base Developers**: Users that want to add new core functionalities or fix bugs in the core capabilities of `PowerSimulations.jl`.

`PowerSimulations.jl` is an active project under development, and we welcome your feedback,
suggestions, and bug reports.

**Note**: `PowerSimulations.jl` uses the data model implemented in [`PowerSystems.jl`](https://github.com/NREL-Sienna/PowerSystems.jl)
to construct optimization models. In most cases, you need to add `PowerSystems.jl` to your scripts.

### Installation

An appropriate optimization solver is required for running PowerSimulations models. Refer to [`JuMP.jl` solver's page](https://jump.dev/JuMP.jl/stable/installation/#Install-a-solver) to select the most appropriate for the application of interest.

## From: Quick Start Guide

  - **Julia:** If this is your first time using Julia visit our [Introduction to Julia](https://nrel-Sienna.github.io/SIIP-Tutorial/fundamentals/introduction-to-julia/) and the official [Getting started with Julia](https://julialang.org/learning/).
  - **Package Installation:** If you want to install packages check the [Package Manager](https://pkgdocs.julialang.org/v1/environments/) instructions, or you can refer to the [PowerSimulations installation instructions](@ref Installation).
  - **PowerSystems:** [PowerSystems.jl](https://github.com/nrel-Sienna/PowerSystems.jl) manages the data and is a fundamental dependency of PowerSimulations.jl. Check the [PowerSystems.jl Basics Tutorial](https://nrel-sienna.github.io/PowerSystems.jl/stable/tutorials/basics/) and [PowerSystems.jl documentation](https://nrel-Sienna.github.io/PowerSystems.jl/stable/) to understand how the inputs to the models are organized.
  - **Dataset Library:** If you don't have a data set to start using `PowerSimulations.jl` check the test systems provided in [`PowerSystemCaseBuilder.jl`](https://nrel-sienna.github.io/PowerSystems.jl/stable/tutorials/powersystembuilder/)

!!! tip
    
    If you need to develop a dataset for a simulation check the [PowerSystems.jl Tutorials](https://nrel-sienna.github.io/PowerSystems.jl/stable/tutorials/basics/) on how to parse data and attach time series

  - **Tutorial:** If you are eager to run your first simulation visit the Solve a Day Ahead Market Scheduling Problem using PowerSimulations.jl tutorial

## From: Modeler Guide

### Modeling FAQ

!!! question "How do I reduce the amount of print on my REPL?"
    
    The print to the REPL is controlled with the logging. Check the [Logging](@ref) documentation page to see how to reduce the print out

!!! question "How do I print the optimizer logs to see the solution process?"
    
    When specifying the `DecisionModel` or `EmulationModel` pass the keyword `print_optimizer_log = true`

### Simulation
!!! tip "Always try to solve the operations problem first before putting together the simulation"
    
    It is not uncommon that when trying to solve a complex simulation the resulting models are infeasible. This situation can be the result of many factors like the input data, the incorrect specification of the initial conditions for models with time dependencies or a poorly specified model. Therefore, it's highly recommended to run and analyze an [Operations Problems](@ref psi_structure) that reflect the problems that will be included in a simulation prior to executing a simulation.

Check out the [Operations Problem Tutorial](@ref op_problem_tutorial)


### Simulation/Simulation Setup
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