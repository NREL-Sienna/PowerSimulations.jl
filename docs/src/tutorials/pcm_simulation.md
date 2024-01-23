# [Sequential Simulations with [PowerSimulations.jl](https://github.com/NREL-SIIP/PowerSimulations.jl)](@id pcm_tutorial)

**Originally Contributed by**: Clayton Barrows

## Introduction

PowerSimulations.jl supports simulations that consist of sequential optimization problems
where results from previous problems inform subsequent problems in a variety of ways. This
example demonstrates some of these capabilities to represent electricity market clearing.
This example is intended to be an extension of the
[OperationsProblem tutorial.](@ref op_problem_tutorial)

### Load Packages

```@example pcm
using PowerSystems
using PowerSimulations
using HydroPowerSimulations
const PSI = PowerSimulations
using PowerSystemCaseBuilder
using Dates
using HiGHS #solver
```

### Optimizer

It's most convenient to define an optimizer instance upfront and pass it into the
`DecisionModel` constructor. For this example, we can use the free HiGHS solver with a
relatively relaxed MIP gap (`ratioGap`) setting to improve speed.

```@example pcm
solver = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.5)
```

### Hourly day-ahead system

First, we'll create a `System` with hourly data to represent day-ahead forecasted wind,
solar, and load profiles:

```@example pcm
sys_DA = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
```

### 5-Minute system

The RTS data also includes 5-minute resolution time series data. So, we can create another
`System` to represent 15 minute ahead forecasted data for a "real-time" market:

```@example pcm
sys_RT = build_system(PSISystems, "modified_RTS_GMLC_RT_sys")
```

## `ProblemTemplate`s define stages

Sequential simulations in PowerSimulations are created by defining `OperationsProblems`
that represent stages, and how information flows between executions of a stage and
between different stages.

Let's start by defining a two stage simulation that might look like a typical day-Ahead
and real-time electricity market clearing process.

### Day-ahead unit commitment stage

First, we can define a unit commitment template for the day ahead problem. We can use the
included UC template, but in this example, we'll replace the `ThermalBasicUnitCommitment`
with the slightly more complex `ThermalStandardUnitCommitment` for the thermal generators.

```@example pcm
template_uc = template_unit_commitment()
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)
```

### Define the reference model for the real-time economic dispatch

In addition to the manual specification process demonstrated in the OperationsProblem
example, PSI also provides pre-specified templates for some standard problems:

```@example pcm
template_ed = template_economic_dispatch(
    network = NetworkModel(PTDFPowerModel, use_slacks = true),
)
```

### Define the `SimulationModels`

`DecisionModel`s define the problems that are executed in the simulation.
The actual problem will change as the stage gets updated to represent
different time periods, but the formulations applied to the components is constant within
a stage. In this case, we want to define two stages with the `ProblemTemplate`s
and the `System`s that we've already created.

```@example pcm
models = SimulationModels(
    decision_models = [
        DecisionModel(template_uc, sys_DA, optimizer = solver, name = "UC"),
        DecisionModel(template_ed, sys_RT, optimizer = solver, name = "ED"),
    ],
)
```

### `SimulationSequence`

Similar to an `ProblemTemplate`, the `SimulationSequence` provides a template of
how to execute a sequential set of operations problems.

Let's review some of the `SimulationSequence` arguments.

### Chronologies

In PowerSimulations, chronologies define where information is flowing. There are two types
of chronologies.

- inter-stage chronologies: Define how information flows between stages. e.g. day-ahead solutions are used to inform economic dispatch problems
- intra-stage chronologies: Define how information flows between multiple executions of a single stage. e.g. the dispatch setpoints of the first period of an economic dispatch problem are constrained by the ramping limits from setpoints in the final period of the previous problem.

### `FeedForward`

The definition of exactly what information is passed using the defined chronologies is
accomplished with `FeedForward`. Specifically, `FeedForward` is used
to define what to do with information being passed with an inter-stage chronology. Let's
define a `FeedForward` that affects the semi-continuous range constraints of thermal generators
in the economic dispatch problems based on the value of the unit-commitment variables.

```@example pcm
feedforward = Dict(
    "ED" => [
        SemiContinuousFeedforward(
            component_type = ThermalStandard,
            source = OnVariable,
            affected_values = [ActivePowerVariable],
        ),
    ],
)
```

### Sequencing

The stage problem length, look-ahead, and other details surrounding the temporal Sequencing
of stages are controlled using the structure of the time series data in the `System`s.
So, to define a typical day-ahead - real-time sequence:

- Day ahead problems should represent 48 hours, advancing 24 hours after each execution (24-hour look-ahead)
- Real time problems should represent 1 hour (12 5-minute periods), advancing 15 min after each execution (15 min look-ahead)

We can adjust the time series data to reflect this structure in each `System`:

- `transform_single_time_series!(sys_DA, 48, Hour(1))`
- `transform_single_time_series!(sys_RT, 12, Minute(15))`


Now we can put it all together to define a `SimulationSequence`

```@example pcm
DA_RT_sequence = SimulationSequence(
    models = models,
    ini_cond_chronology = InterProblemChronology(),
    feedforwards = feedforward,
)
```

## `Simulation`

Now, we can build and execute a simulation using the `SimulationSequence` and `Stage`s
that we've defined.

```@example pcm
sim = Simulation(
    name = "rts-test",
    steps = 2,
    models = models,
    sequence = DA_RT_sequence,
    simulation_folder = mktempdir(".", cleanup = true),
)
```

### Build simulation

```@example pcm
build!(sim)
```

### Execute simulation

the following command returns the status of the simulation (0: is proper execution) and
stores the results in a set of HDF5 files on disk.

```@example pcm
execute!(sim, enable_progress_bar = false)
```

## Results

To access the results, we need to load the simulation result metadata and then make
requests to the specific data of interest. This allows you to efficiently access the
results of interest without overloading resources.

```@example pcm
results = SimulationResults(sim);
uc_results = get_decision_problem_results(results, "UC"); # UC stage result metadata
ed_results = get_decision_problem_results(results, "ED"); # ED stage result metadata
```

We can read all the result variables

```@example pcm
read_variables(uc_results)
```

or all the parameters

```@example pcm
read_parameters(uc_results)
```

We can just list the variable names contained in `uc_results`:

```@example pcm
list_variable_names(uc_results)
```

and a number of parameters (this pattern also works for aux_variables, expressions, and duals)

```@example pcm
list_parameter_names(uc_results)
```

Now we can read the specific results of interest for a specific problem, time window (optional),
and set of variables, duals, or parameters (optional)

```@example pcm
Dict([
    v => read_variable(uc_results, v) for v in [
        "ActivePowerVariable__RenewableDispatch",
        "ActivePowerVariable__HydroDispatch",
        "StopVariable__ThermalStandard",
    ]
])
```

Or if we want the result of just one variable, parameter, or dual (must be defined in the
problem definition), we can use:

```@example pcm
read_parameter(
    ed_results,
    "ActivePowerTimeSeriesParameter__RenewableFix",
    initial_time = DateTime("2020-01-01T06:00:00"),
    count = 5,
)
```

* note that this returns the results of each execution step in a separate dataframe *
If you want the realized results (without lookahead periods), you can call `read_realized_*`:

```@example pcm
read_realized_variables(
    uc_results,
    ["ActivePowerVariable__ThermalStandard", "ActivePowerVariable__RenewableDispatch"],
)
```

## Plotting

Take a look at the plotting capabilities in [PowerGraphics.jl](https://github.com/nrel-siip/powergraphics.jl)
