# [Operations problems with [PowerSimulations.jl](https://github.com/NREL-Sienna/PowerSimulations.jl)](@id op_problem_tutorial)

**Originally Contributed by**: Clayton Barrows

## Introduction

PowerSimulations.jl supports the construction and solution of optimal power system
scheduling problems (Operations Problems). Operations problems form the fundamental
building blocks for sequential simulations. This example shows how to specify and customize a the mathematics that will be applied to the data with an `ProblemTemplate`, build and execute an `DecisionModel`, and access the results.

## Load Packages

```@example op_problem
using PowerSystems
using PowerSimulations
using HydroPowerSimulations
using PowerSystemCaseBuilder
using HiGHS # solver
using Dates
```

## Data

!!! note
    `PowerSystemCaseBuilder.jl` is a helper library that makes it easier to reproduce examples in the documentation and tutorials. Normally you would pass your local files to create the system data instead of calling the function `build_system`.
    For more details visit [PowerSystemCaseBuilder Documentation](https://nrel-sienna.github.io/PowerSystems.jl/stable/tutorials/powersystembuilder/)

```@example op_problem
sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
```

## Define a problem specification with an `ProblemTemplate`

You can create an empty template with:

```@example op_problem
template_uc = ProblemTemplate()
```

Now, you can add a `DeviceModel` for each device type to create an assignment between PowerSystems device types
and the subtypes of `AbstractDeviceFormulation`. PowerSimulations has a variety of different
`AbstractDeviceFormulation` subtypes that can be applied to different PowerSystems device types,
each dispatching to different methods for populating optimization problem objectives, variables,
and constraints. Documentation on the formulation options for various devices can be found in the [formulation library docs](https://nrel-sienna.github.io/PowerSimulations.jl/latest/formulation_library/General/#formulation_library)

### Branch Formulations

Here is an example of relatively standard branch formulations. Other formulations allow
for selective enforcement of transmission limits and greater control on transformer settings.

```@example op_problem
set_device_model!(template_uc, Line, StaticBranch)
set_device_model!(template_uc, Transformer2W, StaticBranch)
set_device_model!(template_uc, TapTransformer, StaticBranch)
```

### Injection Device Formulations

Here we define template entries for all devices that inject or withdraw power on the
network. For each device type, we can define a distinct `AbstractDeviceFormulation`. In
this case, we're defining a basic unit commitment model for thermal generators,
curtailable renewable generators, and fixed dispatch (net-load reduction) formulations
for `HydroDispatch` and `RenewableNonDispatch` devices.

```@example op_problem
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)
set_device_model!(template_uc, RenewableNonDispatch, FixedOutput)
```

### Service Formulations

We have two `VariableReserve` types, parameterized by their direction. So, similar to
creating `DeviceModel`s, we can create `ServiceModel`s. The primary difference being
that `DeviceModel` objects define how constraints get created, while `ServiceModel` objects
define how constraints get modified.

```@example op_problem
set_service_model!(template_uc, VariableReserve{ReserveUp}, RangeReserve)
set_service_model!(template_uc, VariableReserve{ReserveDown}, RangeReserve)
```

### Network Formulations

Finally, we can define the transmission network specification that we'd like to model. For simplicity, we'll
choose a copper plate formulation. But there are dozens of specifications available through
an integration with [PowerModels.jl](https://github.com/lanl-ansi/powermodels.jl). *Note that
many formulations will require appropriate data and may be computationally intractable*

```@example op_problem
set_network_model!(template_uc, NetworkModel(CopperPlatePowerModel))
```

## `DecisionModel`

Now that we have a `System` and an `ProblemTemplate`, we can put the two together
to create an `DecisionModel` that we solve.

### Optimizer

It's most convenient to define an optimizer instance upfront and pass it into the
`DecisionModel` constructor. For this example, we can use the free HiGHS solver with a
relatively relaxed MIP gap (`ratioGap`) setting to improve speed.

```@example op_problem
solver = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.5)
```

### Build an `DecisionModel`

The construction of an `DecisionModel` essentially applies an `ProblemTemplate`
to `System` data to create a JuMP model.

```@example op_problem
problem = DecisionModel(template_uc, sys; optimizer = solver, horizon = Hour(24))
build!(problem, output_dir = mktempdir())
```

!!! tip
    The principal component of the `DecisionModel` is the JuMP model. But you can serialize to a file using the following command:
    ```julia
        serialize_optimization_model(problem, save_path)
    ```
    Keep in mind that if the setting "store_variable_names" is set to `False` then the file won't show the model's names.

### Solve an `DecisionModel`

```@example op_problem
solve!(problem)
```

## Results Inspection

PowerSimulations collects the `DecisionModel` results into a `OptimizationProblemResults` struct:

```@example op_problem
res = OptimizationProblemResults(problem)
```

### Optimizer Stats

The optimizer summary is included

```@example op_problem
get_optimizer_stats(res)
```

### Objective Function Value

```@example op_problem
get_objective_value(res)
```

### Variable, Parameter, Auxillary Variable, Dual, and Expression Values

The solution value data frames for variables, parameters, auxillary variables, duals and
expressions can be accessed using the `read_` methods:

```@example op_problem
read_variables(res)
```

Or, you can read a single parameter values for parameters that exist in the results.

```@example op_problem
list_parameter_names(res)
read_parameter(res, "ActivePowerTimeSeriesParameter__RenewableDispatch")
```

## Plotting

Take a look at the plotting capabilities in [PowerGraphics.jl](https://github.com/nrel-siip/powergraphics.jl)
