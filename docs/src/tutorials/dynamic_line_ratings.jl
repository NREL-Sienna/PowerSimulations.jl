#!nb # ```@meta
#!nb # EditURL = "dynamic_line_ratings.jl"
#!nb # ```
#!nb #
# # [Using Dynamic Line Ratings in PowerSimulations.jl](@id dynamic_line_ratings_tutorial)
#
# **Originally Contributed by**: Sienna Development Team
#
# ## Introduction
#
# This tutorial demonstrates how to incorporate dynamic line ratings (DLR) into unit commitment 
# and economic dispatch problems using PowerSimulations.jl. Dynamic line ratings allow transmission 
# line and transformer capacities to vary over time based on environmental conditions such as 
# temperature, wind speed, and solar radiation. This capability enables more efficient use of 
# transmission infrastructure while maintaining system reliability.
#
# In this example, we will:
#
#   - Load and configure a power system
#   - Add time-varying rating data to AC transmission branches
#   - Configure device models to use dynamic ratings
#   - Build and solve an optimization problem with DLR constraints
#   - Analyze the results
#
# ## Load Required Packages
#
# We begin by loading all necessary packages for this tutorial:

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
using DataStructures

# ## Adding Dynamic Line Ratings to System Branches
#
# The key to implementing dynamic line ratings is creating a time series that represents the 
# rating variations over the simulation horizon. We define a helper function to add DLR time 
# series to specified branches in the system.
#
# ### Define the DLR Helper Function
#
# This function adds dynamic line rating time series data to selected branches:

function add_dlr_to_system_branches!(
    sys::System,
    branches_dlr::Vector{String},
    n_steps::Int,
    dlr_factors::Vector{Float64};
    initial_date::String = "2020-01-01",
)
    for branch_name in branches_dlr
        branch = get_component(ACTransmission, sys, branch_name)
        rating_value = get_rating(branch)
        data = dlr_factors .* rating_value
        time_stamp = range(
            DateTime(initial_date);
            length = n_steps,
            step = Hour(1),
        )
        ta = TimeArray(time_stamp, data)
        ts_single = SingleTimeSeries("dynamic_line_ratings", ta)
        add_time_series!(
            sys,
            branch,
            ts_single;
            features...,
            scaling_factor_multiplier = get_rating,
        )
    end
end

# The function takes:
#
#   - `sys`: The power system object
#   - `branches_dlr`: A vector of branch names to apply DLR
#   - `n_steps`: Number of time steps in the time series
#   - `dlr_factors`: Vector of scaling factors (multipliers applied to the base rating)
#   - `initial_date`: Starting date for the time series, which should be consistent with the dates 
#     in the already stored time series.
#
# The `scaling_factor_multiplier = get_rating` argument tells PowerSystems to multiply the time 
# series values by the base rating of each branch.
#
# ## System Setup and Configuration
#
# ### Configure the Optimizer
#
# We configure the Xpress optimizer with a MIP gap tolerance:

mip_gap = 0.01
optimizer = optimizer_with_attributes(
    HiGHS.Optimizer,
    "mip_rel_gap" => mip_gap)

# ### Load the Test System
#
# We use the modified IEEE RTS-GMLC system from PowerSystemCaseBuilder:

sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")

# ### Create DLR Time Series Data
#
# We create a daily pattern of rating factors that repeats over the simulation horizon:

steps_ts_horizon = 366
initial_date = "2020-01-01"
dlr_factors_daily = vcat([fill(x, 6) for x in [1.0, 0.98, 0.95, 0.95]]...)
dlr_factor_ts_horizon = repeat(dlr_factors_daily, steps_ts_horizon)

# This creates a daily pattern where:
#
#   - Hours 0-5: 100% of base rating
#   - Hours 6-11: 98% of base rating
#   - Hours 12-17: 95% of base rating
#   - Hours 18-23: 95% of base rating
#
# ### Specify Branches with DLR
#
# We define which branches will have dynamic ratings applied:

branches_dlr_v = ["A2", "AB1", "A24", "B10", "B18", "CA-1", "C22", "C34",
    "A7", "A17", "B14", "B15", "C7", "C17"]

# ### Apply DLR to the System
#
# Now we add the DLR time series to all specified branches:

add_dlr_to_system_branches!(
    sys,
    branches_dlr_v,
    steps_ts_horizon,
    dlr_factor_ts_horizon,
)

# ### Transform Time Series
#
# We transform all instances of SingleTimeSeries in a System to DeterministicSingleTimeSeries 
# suitable for the optimization problem:

transform_single_time_series!(sys, Hour(48), Day(1))

# This creates 48-hour forecast windows.
#
# ## Building the Optimization Problem Template
#
# ### Create Network Model
#
# We set up a PTDF-based network model for efficient DC power flow representation:

template_uc = ProblemTemplate(
    NetworkModel(PTDFPowerModel;
        reduce_radial_branches = false,
        duals = [CopperPlateBalanceConstraint],
        use_slacks = true,
        PTDF_matrix = PTDF(sys),
    ),
)

# ### Configure Generation Device Models
#
# We define formulations for various generation types:

set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, RenewableNonDispatch, FixedOutput)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)

# ### Configure Branch Models with Dynamic Ratings
#
# This is the critical step for incorporating DLR into the optimization problem. We create 
# device models for lines and transformers that reference the dynamic line ratings time series:

line_device_model = DeviceModel(
    Line,
    StaticBranch;
    time_series_names = Dict(
        DynamicBranchRatingTimeSeriesParameter => "dynamic_line_ratings",
    ),
)

TapTransf_device_model = DeviceModel(
    TapTransformer,
    StaticBranch;
    time_series_names = Dict(
        DynamicBranchRatingTimeSeriesParameter => "dynamic_line_ratings",
    ),
)

# The `time_series_names` dictionary maps the `DynamicBranchRatingTimeSeriesParameter` to the 
# time series name we used when adding data to the system ("dynamic_line_ratings"). This tells 
# PowerSimulations to use time-varying ratings instead of static ratings for these branches.
#
# ### Apply Branch Models to Template

set_device_model!(template_uc, line_device_model)
set_device_model!(template_uc, TapTransf_device_model)
set_device_model!(
    template_uc,
    DeviceModel(TwoTerminalGenericHVDCLine,
        HVDCTwoTerminalLossless),
)

# ### Configure Reserve Services
#
# We add operating reserve requirements to the problem:

set_service_model!(
    template_uc,
    ServiceModel(VariableReserve{ReserveUp}, RangeReserve; use_slacks = false),
)
set_service_model!(
    template_uc,
    ServiceModel(VariableReserve{ReserveDown}, RangeReserve; use_slacks = false),
)

# ## Building and Executing the Decision Model
#
# ### Create the Decision Model
#
# We instantiate a `DecisionModel` with our configured template:

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

# ### Configure Simulation
#
# For multi-stage problems or rolling horizon simulations, we set up the simulation structure:

models = SimulationModels(;
    decision_models = [model],
)

DA_sequence = SimulationSequence(;
    models = models,
    ini_cond_chronology = InterProblemChronology(),
)

current_date = string(today())
steps_sim = 2
sim = Simulation(;
    name = current_date * "_RTS_DA" * "_" * string(steps_sim) * "steps",
    steps = steps_sim,
    models = models,
    initial_time = DateTime(string(initial_date, "T00:00:00")),
    sequence = DA_sequence,
    simulation_folder = tempdir())

# ### Build and Execute

build!(sim; console_level = Logging.Info)
execute!(sim)

# ## Analyzing Results
#
# After execution, we can extract and analyze the results:

results = SimulationResults(sim)
uc = get_decision_problem_results(results, "UC")

Pline_df =
    read_realized_expression(uc, "PTDFBranchFlow__Line"; table_format = TableFormat.WIDE)
PTrafo_df = read_realized_expression(
    uc,
    "PTDFBranchFlow__TapTransformer";
    table_format = TableFormat.WIDE,
)

Pline_dlr_df = Pline_df[:, ["A2", "AB1", "A24", "B10", "B18", "CA-1", "C22", "C34"]]
PTrafo_dlr_df = PTrafo_df[:, ["A7", "A17"]]

# The results show power flows on branches with dynamic ratings. These flows should respect 
# the time-varying limits imposed by the DLR time series throughout the optimization horizon.
#
# For instance, `Pline_dlr_df` should look like this, where it is possible to verify that the 
# limits imposed by the previously defined DLRs:
#
# ```
# 48×8 DataFrame
#  Row │ A2          AB1       A24      B10       B18        CA-1       C22        C34       
#      │ Float64     Float64   Float64  Float64   Float64    Float64    Float64    Float64
# ─────┼─────────────────────────────────────────────────────────────────────────────────────
#    1 │ -52.1503    112.611   179.751  -49.8023   -47.4157  -159.183    -78.4443  -35.8727
#    2 │ -52.4493    107.858   179.495  -50.6261   -47.5525  -157.746    -78.1694  -36.0756
#   ...
# ```
#
# It is possible to explore the DLRs of each line using:

dlrs_dict = read_parameter(
    uc,
    "DynamicBranchRatingTimeSeriesParameter__Line";
    table_format = TableFormat.WIDE,
)
keys_dlrs = collect(keys(dlrs_dict))
dlrs_dict[keys_dlrs[1]]

# It is possible to print `dlrs_dict[keys_dlrs[1]]` which results in:
#
# ```
# 48×9 DataFrame
#  Row │ DateTime             CA-1     AB1      A2       A24      B10      C22      C34      B18     
#      │ DateTime             Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64
# ─────┼─────────────────────────────────────────────────────────────────────────────────────────────
#    1 │ 2020-01-01T00:00:00    575.0   201.25   201.25    575.0   201.25    575.0    575.0    575.0
#    2 │ 2020-01-01T01:00:00    575.0   201.25   201.25    575.0   201.25    575.0    575.0    575.0
#   ...
# ```
#
# If you run the same problem but neglecting the DLRs, `Pline_dlr_df` results in different flows.
# For instance, it is possible to notice some differences in the flows through line "AB1" from 
# time-step 42 to 44 since in the DLR case by the end of each day the line flow is constrained 
# to 95% of its rating.
