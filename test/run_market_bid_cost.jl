using Pkg
Pkg.activate("test")
Pkg.instantiate()

using Revise
using PowerSystems
using PowerSystemCaseBuilder
using PowerSimulations
using StorageSystemsSimulations
using HydroPowerSimulations
using Xpress
using Logging
# using PlotlyJS
using Dates
using JuMP
using InfrastructureSystems
using DataStructures
using TimeSeries
const PSY = PowerSystems
const PSI = PowerSimulations
const PSB = PowerSystemCaseBuilder
const PM = PSI.PowerModels

##################################
### Load Test Function Helpers ###
##################################

include("test_utils/solver_definitions.jl")
include("test_utils/operations_problem_templates.jl")

sys = PSB.build_system(PSITestSystems, "c_sys5_re")

show_components(sys, ThermalStandard, [:active_power])
show_components(sys, RenewableDispatch, [:active_power])

th_solitude = get_component(ThermalStandard, sys, "Solitude")
th_brighton = get_component(ThermalStandard, sys, "Brighton")
re_A = get_component(RenewableDispatch, sys, "WindBusA")
get_bus(th_solitude)

#### Add MarketBidCost

proposed_offer_curve = make_market_bid_curve(
    [0.0, 100.0, 200.0, 300.0, 400.0, 500.0, 600.0], 
    [25.0, 25.5, 26.0, 27.0, 28.0, 30.0], 
    10.0
)

set_operation_cost!(
    th_solitude, 
    MarketBidCost(;
    no_load_cost=0.0, 
    start_up = (hot=3.0, warm=0.0, cold=0.0), 
    shut_down = 1.5, 
    incremental_offer_curves = proposed_offer_curve
    )
)

#### PowerSimulations Stuff ###

template = ProblemTemplate(
    NetworkModel(
        CopperPlatePowerModel;
        duals = [CopperPlateBalanceConstraint],
    ),
)
set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
#set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
set_device_model!(template, PowerLoad, StaticPowerLoad)
set_device_model!(template, RenewableDispatch, RenewableFullDispatch)

model = DecisionModel(
    template,
    sys;
    name = "UC",
    optimizer = optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 1e-3),
    system_to_file = false,
    store_variable_names = true,
    calculate_conflict = true,
    optimizer_solve_log_print = true,
)

build!(model; output_dir = mktempdir(; cleanup = true))

vars = model.internal.container.variables
cons = model.internal.container.constraints

power_balance =
    cons[PowerSimulations.ConstraintKey{CopperPlateBalanceConstraint, System}("")]
lb_thermal = cons[PowerSimulations.ConstraintKey{
    ActivePowerVariableLimitsConstraint,
    ThermalStandard,
}(
    "lb",
)]

solve!(model)

res = OptimizationProblemResults(model)

p_th = read_variable(res, "ActivePowerVariable__ThermalStandard")

param_re = read_parameter(res, "ActivePowerTimeSeriesParameter__RenewableDispatch")
p_re = read_variable(res, "ActivePowerVariable__RenewableDispatch")

# $/(per-unit MW) = $/(100 MW) = 0.01 $/MW
price = read_dual(res, "CopperPlateBalanceConstraint__System")