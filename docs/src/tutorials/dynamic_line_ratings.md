# [Using Dynamic Line Ratings in PowerSimulations.jl](@id dynamic_line_ratings_tutorial)

**Originally Contributed by**: Sienna Development Team

## Introduction

This tutorial demonstrates how to incorporate dynamic line ratings (DLR) into unit commitment and economic dispatch problems using PowerSimulations.jl. Dynamic line ratings allow transmission line and transformer capacities to vary over time based on environmental conditions such as temperature, wind speed, and solar radiation. This capability enables more efficient use of transmission infrastructure while maintaining system reliability.

In this example, we will:
- Load and configure a power system
- Add time-varying rating data to AC transmission branches
- Configure device models to use dynamic ratings
- Build and solve an optimization problem with DLR constraints
- Analyze the results

## Load Required Packages

We begin by loading all necessary packages for this tutorial:

```julia
using Revise
using Logging
using InfrastructureSystems
using PowerSystems
using PowerSystemCaseBuilder
using PowerSimulations
using HydroPowerSimulations
using PowerFlows
using PowerNetworkMatrices
using HiGHS
using DataFrames
using Dates
using TimeSeries
using Xpress
using DataStructures
```

## Adding Dynamic Line Ratings to System Branches

The key to implementing dynamic line ratings is creating a time series that represents the rating variations over the simulation horizon. We define a helper function to add DLR time series to specified branches in the system.

### Define the DLR Helper Function

This function adds dynamic line rating time series data to selected branches:

```julia
function add_dlr_to_system_branches!(
    sys::System, 
    branches_dlr::Vector{String},
    n_steps::Int, 
    dlr_factors::Vector{Float64};
    initial_date::String = "2020-01-01",
    )
    for branch_name in branches_dlr
        branch = get_component(ACTransmission, sys, branch_name)

        data_ts = collect(
            DateTime("$initial_date 0:00:00", "y-m-d H:M:S"):Hour(1):(
                DateTime("$initial_date 23:00:00", "y-m-d H:M:S") + Day(n_steps-1)
            )
        )
        
        dlr_data = TimeArray(data_ts, dlr_factors)

        PowerSystems.add_time_series!(
            sys,
            branch,
            PowerSystems.SingleTimeSeries(
                "dynamic_line_ratings",
                dlr_data;
                scaling_factor_multiplier = get_rating,
            ),
        )
    end
end
```

The function takes:
- `sys`: The power system object
- `branches_dlr`: A vector of branch names to apply DLR
- `n_steps`: Number of time steps in the time series
- `dlr_factors`: Vector of scaling factors (multipliers applied to the base rating)
- `initial_date`: Starting date for the time series, which should be consistent with the dates in the already stored time series.

The `scaling_factor_multiplier = get_rating` argument tells PowerSystems to multiply the time series values by the base rating of each branch.

## System Setup and Configuration

### Configure the Optimizer

We configure the Xpress optimizer with a MIP gap tolerance:

```julia
mip_gap = 0.01
optimizer = optimizer_with_attributes(
    Xpress.Optimizer,
    "MIPRELSTOP" => mip_gap)
```

### Load the Test System

We use the modified IEEE RTS-GMLC system from PowerSystemCaseBuilder:

```julia
sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
```

### Create DLR Time Series Data

We create a daily pattern of rating factors that repeats over the simulation horizon:

```julia
steps_ts_horizon = 366 
initial_date = "2020-01-01"
dlr_factors_daily = vcat([fill(x, 6) for x in [1.15, 1.05, 0.95, 0.95]]...)
dlr_factor_ts_horizon = repeat(dlr_factors_daily, steps_ts_horizon)
```

This creates a daily pattern where:
- Hours 0-5: 115% of base rating
- Hours 6-11: 105% of base rating  
- Hours 12-17: 95% of base rating
- Hours 18-23: 95% of base rating

### Specify Branches with DLR

We define which branches will have dynamic ratings applied:

```julia
branches_dlr_v = ["A2", "AB1", "A24", "B10","B18", "CA-1", "C22", "C34",
                  "A7", "A17", "B14", "B15", "C7", "C17"]
```

### Apply DLR to the System

Now we add the DLR time series to all specified branches:

```julia
add_dlr_to_system_branches!(
    sys,
    branches_dlr_v,
    steps_ts_horizon,
    dlr_factor_ts_horizon,
)
```

### Transform Time Series

We transform  all instances of SingleTimeSeries in a System to DeterministicSingleTimeSeries suitable for the optimization problem:

```julia
transform_single_time_series!(sys, Hour(48), Day(1))
```

This creates 48-hour forecast windows.

## Building the Optimization Problem Template

### Create Network Model

We set up a PTDF-based network model for efficient DC power flow representation:

```julia
template_uc = ProblemTemplate(
    NetworkModel(PTDFPowerModel;
        reduce_radial_branches = false,
        use_slacks = false,
        PTDF_matrix = PTDF(sys),
    ),
)
```

### Configure Generation Device Models

We define formulations for various generation types:

```julia
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, RenewableNonDispatch, FixedOutput)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)
```

### Configure Branch Models with Dynamic Ratings

This is the critical step for incorporating DLR into the optimization problem. We create device models for lines and transformers that reference the dynamic line ratings time series:

```julia
line_device_model = DeviceModel(
    Line,
    StaticBranch;
    time_series_names = Dict(
        DynamicBranchRatingTimeSeriesParameter => "dynamic_line_ratings",
    )
)

TapTransf_device_model = DeviceModel(
    TapTransformer,
    StaticBranch;
    time_series_names = Dict(
        DynamicBranchRatingTimeSeriesParameter => "dynamic_line_ratings",
    )
)
```

The `time_series_names` dictionary maps the `DynamicBranchRatingTimeSeriesParameter` to the time series name we used when adding data to the system ("dynamic_line_ratings"). This tells PowerSimulations to use time-varying ratings instead of static ratings for these branches.

### Apply Branch Models to Template

```julia
set_device_model!(template_uc, line_device_model)
set_device_model!(template_uc, TapTransf_device_model)
set_device_model!(template_uc, DeviceModel(TwoTerminalGenericHVDCLine,
                                    HVDCTwoTerminalLossless))
```

### Configure Reserve Services

We add operating reserve requirements to the problem:

```julia
set_service_model!(
    template_uc,
    ServiceModel(VariableReserve{ReserveUp}, RangeReserve, use_slacks = false) 
)
set_service_model!(
    template_uc,
    ServiceModel(VariableReserve{ReserveDown}, RangeReserve, use_slacks = false)
)
```

## Building and Executing the Decision Model

### Create the Decision Model

We instantiate a `DecisionModel` with our configured template:

```julia
model = DecisionModel(
    template_uc,
    sys;
    name = "UC",
    optimizer = optimizer,
    system_to_file = false,
    initialize_model = true,
    check_numerical_bounds = false,
    optimizer_solve_log_print = true,
    direct_mode_optimizer = false,
    rebuild_model = false,
    store_variable_names = true,
    calculate_conflict = false,
)
```

### Configure Simulation

For multi-stage problems or rolling horizon simulations, we set up the simulation structure:

```julia
models = SimulationModels(
    decision_models = [model],
)

DA_sequence = SimulationSequence(
    models = models,
    ini_cond_chronology = InterProblemChronology(),
)

current_date = string(today())
steps_sim = 2
sim = Simulation(
    name = current_date * "_RTS_DA" * "_" * string(steps_sim) * "steps",
    steps = steps_sim,
    models = models,
    initial_time = DateTime(string(initial_date,"T00:00:00")),
    sequence = DA_sequence,
    simulation_folder = tempdir())
```

### Build and Execute

```julia
build!(sim; console_level = Logging.Info)
execute!(sim)
```

## Analyzing Results

After execution, we can extract and analyze the results:

```julia
results = SimulationResults(sim)
uc = get_decision_problem_results(results, "UC")

Pline_df = read_realized_expression(uc, "PTDFBranchFlow__Line", table_format = TableFormat.WIDE)
PTrafo_df = read_realized_expression(uc, "PTDFBranchFlow__TapTransformer", table_format = TableFormat.WIDE)

Pline_dlr_df = Pline_df[:, ["A2", "AB1", "A24", "B10","B18", "CA-1", "C22", "C34"]]
PTrafo_dlr_df = PTrafo_df[:, ["A7", "A17"]]
```

The results show power flows on branches with dynamic ratings. These flows should respect the time-varying limits imposed by the DLR time series throughout the optimization horizon.

For instance, ``Pline_dlr_df`` should look like this, where it is possible to verify that the limits imposed by the previously defined DLRs:
```
48×8 DataFrame
 Row │ A2          AB1       A24      B10       B18        CA-1       C22        C34       
     │ Float64     Float64   Float64  Float64   Float64    Float64    Float64    Float64
─────┼─────────────────────────────────────────────────────────────────────────────────────
   1 │ -52.1503    112.611   179.751  -49.8023   -47.4157  -159.183    -78.4443  -35.8727
   2 │ -52.4493    107.858   179.495  -50.6261   -47.5525  -157.746    -78.1694  -36.0756
   3 │ -52.2131    110.331   176.241  -50.3657   -47.5569  -157.288    -79.3839  -34.7969
   4 │ -53.1428    108.341   176.846  -50.5155   -49.016   -145.045    -72.1242  -34.7698
   5 │ -27.1763    113.267   166.088  -41.9557   -42.758   -161.911    -78.5576  -34.0575
   6 │ -21.4108    120.857   180.489  -42.8128   -38.5824  -241.355   -100.032   -32.6504
   7 │ -27.0544    147.775   187.422  -46.3586   -37.9729  -194.697   -162.016   -30.2505
   8 │  21.3976    123.875   148.28   -43.2168   -15.4891  -243.931    -98.5133   -9.91997
   9 │  35.3728    129.006   161.671  -43.7058   -30.7661  -171.589    -67.4618  -25.1261
  10 │  22.1767    121.591   154.064  -44.935    -38.5415   -69.9699   -45.1058  -20.0578
  ⋮  │     ⋮          ⋮         ⋮        ⋮          ⋮          ⋮          ⋮          ⋮
  39 │  21.5669     52.3964  175.125  -35.6315   -22.2772  -363.64    -114.887   -28.4094
  40 │  19.4448     62.6198  168.627  -31.8984   -13.6121  -396.415   -129.141   -13.8401
  41 │  -0.373175  113.611   176.175  -34.97     -99.1879  -340.648   -130.253   -26.552
  42 │   6.70913   166.25    160.555  -39.1845  -126.471   -422.735   -151.439   -24.7189
  43 │  12.585     164.198   161.833  -38.4486  -119.939   -410.783   -147.292   -25.7665
  44 │   5.67607   145.471   169.259  -41.8964  -124.878   -389.841   -140.328   -26.3622
  45 │   7.665     155.862   128.417  -40.4783  -104.351   -461.416   -143.642   -23.1897
  46 │  -3.54973   111.414   164.922  -41.1089   -84.9369  -370.325   -121.343   -22.3103
  47 │  -6.94597   105.191   183.445  -41.2947   -98.3436  -177.766    -58.6008  -39.5323
  48 │  -8.04915    95.5157  176.346  -40.2376   -92.5097  -198.77     -46.6054  -38.0692
```

It is possible to explore the DLRs of each line using:

```
dlrs_dict = read_parameter(uc, "DynamicBranchRatingTimeSeriesParameter__Line", table_format = TableFormat.WIDE)
keys_dlrs = collect(keys(dlrs_dict))
dlrs_dict[keys_dlrs[1]]
```

It is possible to pront ``dlrs_dict[keys_dlrs[1]]`` which results in:

```
48×9 DataFrame
 Row │ DateTime             CA-1     AB1      A2       A24      B10      C22      C34      B18     
     │ DateTime             Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64
─────┼─────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 2020-01-01T00:00:00    575.0   201.25   201.25    575.0   201.25    575.0    575.0    575.0
   2 │ 2020-01-01T01:00:00    575.0   201.25   201.25    575.0   201.25    575.0    575.0    575.0
   3 │ 2020-01-01T02:00:00    575.0   201.25   201.25    575.0   201.25    575.0    575.0    575.0
   4 │ 2020-01-01T03:00:00    575.0   201.25   201.25    575.0   201.25    575.0    575.0    575.0
   5 │ 2020-01-01T04:00:00    575.0   201.25   201.25    575.0   201.25    575.0    575.0    575.0
   6 │ 2020-01-01T05:00:00    575.0   201.25   201.25    575.0   201.25    575.0    575.0    575.0
   7 │ 2020-01-01T06:00:00    525.0   183.75   183.75    525.0   183.75    525.0    525.0    525.0
   8 │ 2020-01-01T07:00:00    525.0   183.75   183.75    525.0   183.75    525.0    525.0    525.0
   9 │ 2020-01-01T08:00:00    525.0   183.75   183.75    525.0   183.75    525.0    525.0    525.0
  10 │ 2020-01-01T09:00:00    525.0   183.75   183.75    525.0   183.75    525.0    525.0    525.0
  ⋮  │          ⋮              ⋮        ⋮        ⋮        ⋮        ⋮        ⋮        ⋮        ⋮
  39 │ 2020-01-02T14:00:00    475.0   166.25   166.25    475.0   166.25    475.0    475.0    475.0
  40 │ 2020-01-02T15:00:00    475.0   166.25   166.25    475.0   166.25    475.0    475.0    475.0
  41 │ 2020-01-02T16:00:00    475.0   166.25   166.25    475.0   166.25    475.0    475.0    475.0
  42 │ 2020-01-02T17:00:00    475.0   166.25   166.25    475.0   166.25    475.0    475.0    475.0
  43 │ 2020-01-02T18:00:00    475.0   166.25   166.25    475.0   166.25    475.0    475.0    475.0
  44 │ 2020-01-02T19:00:00    475.0   166.25   166.25    475.0   166.25    475.0    475.0    475.0
  45 │ 2020-01-02T20:00:00    475.0   166.25   166.25    475.0   166.25    475.0    475.0    475.0
  46 │ 2020-01-02T21:00:00    475.0   166.25   166.25    475.0   166.25    475.0    475.0    475.0
  47 │ 2020-01-02T22:00:00    475.0   166.25   166.25    475.0   166.25    475.0    475.0    475.0
  48 │ 2020-01-02T23:00:00    475.0   166.25   166.25    475.0   166.25    475.0    475.0    475.0
```

If you run the same problem but neglecting the DLRs, ``Pline_dlr_df`` results in:

```
48×8 DataFrame
 Row │ A2         AB1      A24       B10       B18       CA-1       C22        C34      
     │ Float64    Float64  Float64   Float64   Float64   Float64    Float64    Float64
─────┼──────────────────────────────────────────────────────────────────────────────────
   1 │ -52.0395   112.32   178.857   -49.841   -47.7287  -161.345    -79.4257  -35.8975
   2 │ -51.8803   105.965  174.931   -49.1134  -47.1692  -168.807    -82.9044  -36.2015
   3 │ -42.9571   110.167  169.519   -48.6222  -44.9675  -183.804    -86.3206  -35.4569
   4 │ -41.7656   104.064  168.498   -50.8855  -51.2308  -128.071    -68.2407  -34.5863
   5 │ -33.4647   116.729  163.703   -49.3765  -46.5884  -159.741    -78.2285  -34.0345
   6 │ -38.8947   120.112  179.751   -51.8637  -45.1364  -221.785    -96.9057  -32.0686
   7 │ -38.666    171.599  184.377   -52.9457  -42.9382  -172.687   -159.964   -29.8648
   8 │  11.4355   100.853  130.376   -54.362   -50.1277    32.2224   -57.2809  -30.7669
   9 │  17.0818   128.49   162.018   -51.5859  -38.1308  -150.525    -91.958   -32.7883
  10 │  22.4234   117.477  126.433   -51.4782  -30.421   -134.374    -17.4694  -28.4141
  ⋮  │     ⋮         ⋮        ⋮         ⋮         ⋮          ⋮          ⋮         ⋮
  39 │  57.9761   102.292   86.0389  -33.0666  -29.5337   -34.0263  -155.603   -26.6774
  40 │  35.9545   114.198  157.668   -27.2024  -14.1016  -299.521   -142.207   -27.3215
  41 │   5.76965  147.815  202.0     -27.3904  -22.4638  -319.133   -237.575   -23.7211
  42 │   7.52603  175.0    225.92    -32.589   -30.5996  -227.341   -170.077   -23.0602
  43 │  10.9689   175.0    229.473   -30.9047  -30.265   -216.332   -169.736   -27.5204
  44 │   7.43777  175.0    229.282   -32.9246  -28.4416  -267.902   -160.247   -27.7539
  45 │   1.80524  161.146  230.433   -34.2214  -29.6618  -263.616   -149.755   -25.9966
  46 │   4.32284  140.594  180.199   -33.059   -19.0999  -357.415   -109.76    -22.3154
  47 │  -3.17089  119.776  199.082   -32.9699  -21.8616  -323.837    -79.7315  -38.5204
  48 │  -9.5247   124.305  214.477   -31.2236  -14.4773  -270.202    -56.7522  -38.8242
```
For instance, it is posible to notice some differences in the flows through line "AB1" from time-step 42 to 44 since in the DLR case by the end of each day the line flow is constraind to 95% of its rating.