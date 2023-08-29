using Pkg
Pkg.activate("test")
Pkg.instantiate()
using Revise

using PowerSimulations
using PowerSystems
using PowerSystemCaseBuilder
using InfrastructureSystems
const PSY = PowerSystems
const PSI = PowerSimulations
const PSB = PowerSystemCaseBuilder
using Xpress
using JuMP
using Logging
using Dates
using TimeSeries
using PlotlyJS

include("script_utils.jl")

sys_DA = System("data/sys_DA_1h.json")
sys_RT = System("data/sys_RT_5min.json")

mipgap = 1e-2 # 1%
num_steps = 2
starttime = DateTime("2020-01-01T00:00:00")

template_uc = get_uc_ptdf_template(sys_DA)
set_device_model!(template_uc, ThermalStandard, ThermalBasicUnitCommitment)
template_ed = get_ed_ptdf_template(sys_RT)
set_device_model!(template_ed, ThermalStandard, ThermalBasicDispatch)

models = SimulationModels(;
    decision_models = [
        DecisionModel(
            template_uc,
            sys_DA;
            name = "UC",
            optimizer = optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => mipgap),
            system_to_file = false,
            initialize_model = true,
            optimizer_solve_log_print = false,
            direct_mode_optimizer = true,
            rebuild_model = false,
            store_variable_names = true,
            calculate_conflict = true,
        ),
        DecisionModel(
            template_ed,
            sys_RT;
            name = "ED",
            optimizer = optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => mipgap),
            system_to_file = false,
            initialize_model = true,
            optimizer_solve_log_print = false,
            direct_mode_optimizer = true,
            rebuild_model = false,
            store_variable_names = true,
            calculate_conflict = true,
        ),
    ],
)

# Set-up the sequence UC-ED
sequence = SimulationSequence(;
    models = models,
    feedforwards = Dict(
        "ED" => [
            SemiContinuousFeedforward(;
                component_type = ThermalStandard,
                source = OnVariable,
                affected_values = [ActivePowerVariable],
            ),
            FixValueFeedforward(;
                component_type = VariableReserve{ReserveUp},
                source = ActivePowerReserveVariable,
                affected_values = [ActivePowerReserveVariable],
            ),
            FixValueFeedforward(;
                component_type = VariableReserve{ReserveDown},
                source = ActivePowerReserveVariable,
                affected_values = [ActivePowerReserveVariable],
            ),
        ],
    ),
    ini_cond_chronology = InterProblemChronology(),
)

sim = Simulation(;
    name = "compact_sim",
    steps = num_steps,
    models = models,
    sequence = sequence,
    initial_time = starttime,
    simulation_folder = mktempdir(; cleanup = true),
)

build!(sim; console_level = Logging.Info, serialize = false)
execute!(sim; enable_progress_bar = true);

results_nrb = SimulationResults(sim; ignore_status = true)
results_uc_nrb = get_decision_problem_results(results_nrb, "UC")
results_ed_nrb = get_decision_problem_results(results_nrb, "ED")

regup_uc = read_realized_variable(
    results_uc_nrb,
    "ActivePowerReserveVariable__VariableReserve__ReserveUp__Reg_Up_R1",
)
dates_uc = regup_uc[!, "DateTime"]
regup_uc_st4 = regup_uc[!, "123_STEAM_2"]

regup_ed = read_realized_parameter(
    results_ed_nrb,
    "FixValueParameter__VariableReserve__ReserveUp__Reg_Up_R1",
)
dates_ed = regup_ed[!, "DateTime"]
regup_ed_st4 = regup_ed[!, "123_STEAM_2"]
regup_ed_var = read_realized_variable(
    results_ed_nrb,
    "ActivePowerReserveVariable__VariableReserve__ReserveUp__Reg_Up_R1",
)
regup_ed_var_st4 = regup_ed_var[!, "123_STEAM_2"]

PlotlyJS.plot([
    PlotlyJS.scatter(; x = dates_uc, y = regup_uc_st4, name = "UC", line_shape = "hv"),
    PlotlyJS.scatter(;
        x = dates_ed,
        y = regup_ed_st4 .* 100.0,
        name = "ED",
        line_shape = "hv",
    ),
    PlotlyJS.scatter(;
        x = dates_ed,
        y = regup_ed_var_st4,
        name = "ED Var",
        line_shape = "hv",
    ),
])

uc = sim.models.decision_models[1]
ed = sim.models.decision_models[2]
vars = ed.internal.container.variables
pwl = vars[PSI.VariableKey{PSI.PieceWiseLinearCostVariable, ThermalStandard}("")]
pwl_var = pwl["315_STEAM_1", 1, 1]
p = vars[PSI.VariableKey{ActivePowerVariable, ThermalStandard}("")]
p["315_STEAM_1", 1]
p_stuff = p["315_STEAM_1", :]
p_vals = value.(p_stuff)
value.(regup["324_PV_3", :])

param = ed.internal.container.parameters
on_val = param[PSI.ParameterKey{OnStatusParameter, ThermalStandard}("")].parameter_array
regup3 =
    param[PSI.ParameterKey{FixValueParameter, VariableReserve{ReserveUp}}(
        "Reg_Up_R3",
    )].parameter_array
spinup3 =
    param[PSI.ParameterKey{FixValueParameter, VariableReserve{ReserveUp}}(
        "Spin_Up_R3",
    )].parameter_array
regdown3 =
    param[PSI.ParameterKey{FixValueParameter, VariableReserve{ReserveDown}}(
        "Reg_Down_R3",
    )].parameter_array
regup3["315_STEAM_1", :]
regdown3["315_STEAM_1", :]
spinup3["315_STEAM_1", :]
on_val_steam = JuMP.fix_value.(on_val["315_STEAM_1", :])

g = get_component(ThermalStandard, sys_RT, "315_STEAM_1")
g.bus

var_state = sim.internal.simulation_state.decision_states.variables
on_state = var_state[PSI.VariableKey{OnVariable, ThermalStandard}("")]
regup_state3 =
    var_state[PSI.VariableKey{ActivePowerReserveVariable, VariableReserve{ReserveDown}}(
        "Reg_Down_R3",
    )]
reg_val = regup_state3.values[!, "315_STEAM_1"]

constr = ed.internal.container.constraints
ub_ff = constr[PSI.ConstraintKey{FeedforwardSemiContinousConstraint, ThermalStandard}(
    "ActivePowerVariable_ub",
)]
ub_ff["315_STEAM_1", :]

#=
Name      Type    Sense    Bound 
R3217       row     LE       .0000000:00:00
C4          column  LO       .000000
C1598       column  UP       .000000
C10643      column  LO      1.000000
C11317      column  LO      1.000000
=#

# ActivePowerVariable_ThermalStandard_{322_CT_6, 1} - 0.55 _[1465] + ActivePowerReserveVariable_VariableReserve{ReserveUp}_Reg_Up_R3_{322_CT_6, 1} - x[322_CT_6,1] ≤ 0.0     
