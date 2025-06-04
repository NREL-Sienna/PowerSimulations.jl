#TODO: timeseries market_bid_cost
@testset "Test Thermal Generation MarketBidCost models" begin
    test_cases = [
        ("Base case", "fixed_market_bid_cost", 18487.236, 30.0, 30.0),
        ("Greater initial input, no load", "fixed_market_bid_cost", 18487.236, 31.0, 31.0),
        ("Greater initial input only", "fixed_market_bid_cost", 18487.236, 30.0, 31.0),
    ]
    for (name, sys_name, cost_reference, my_no_load, my_initial_input) in test_cases
        @testset "$name" begin
            sys = build_system(PSITestSystems, "c_$(sys_name)")
            unit1 = get_component(ThermalStandard, sys, "Test Unit1")
            old_fd = get_function_data(
                get_value_curve(get_incremental_offer_curves(get_operation_cost(unit1))),
            )
            new_vc = PiecewiseIncrementalCurve(old_fd, my_initial_input, my_no_load)
            set_incremental_offer_curves!(get_operation_cost(unit1), CostCurve(new_vc))
            set_no_load_cost!(get_operation_cost(unit1), my_no_load)
            template = ProblemTemplate(NetworkModel(CopperPlatePowerModel))
            set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
            set_device_model!(template, PowerLoad, StaticPowerLoad)
            model = DecisionModel(
                template,
                sys;
                name = "UC_$(sys_name)",
                optimizer = HiGHS_optimizer,
                system_to_file = false,
                optimizer_solve_log_print = true,
            )
            @test build!(model; output_dir = test_path) == PSI.ModelBuildStatus.BUILT
            @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
            results = OptimizationProblemResults(model)
            expr = read_expression(results, "ProductionCostExpression__ThermalStandard")
            var_unit_cost = sum(expr[!, "Test Unit1"])
            unit_cost_due_to_initial =
                sum(.~iszero.(expr[!, "Test Unit1"]) .* my_initial_input)
            @test isapprox(
                var_unit_cost,
                cost_reference + unit_cost_due_to_initial;
                atol = 1,
            )
        end
    end
end

"Set the no_load_cost and input_at_zero to `nothing` and the initial_input to the old no_load_cost. Not designed for time series"
function no_load_to_initial_input!(comp::Generator)
    cost = get_operation_cost(comp)::MarketBidCost
    no_load = PSY.get_no_load_cost(cost)
    old_fd = get_function_data(
        get_value_curve(get_incremental_offer_curves(get_operation_cost(comp))),
    )::IS.PiecewiseStepData
    new_vc = PiecewiseIncrementalCurve(old_fd, no_load, nothing)
    set_incremental_offer_curves!(get_operation_cost(comp), CostCurve(new_vc))
    set_no_load_cost!(get_operation_cost(comp), nothing)
    return
end

no_load_to_initial_input!(
    sys::PSY.System,
    sel = make_selector(x -> get_operation_cost(x) isa MarketBidCost, Generator),
) =
    no_load_to_initial_input!.(get_components(sel, sys))

"Helper function to make a time series from an initial value (can be a single number or tuple) and some increments"
function _make_deterministic_ts(
    name,
    ini_val::Union{Number, Tuple},
    res_incr,
    interval_incr,
    horizon,
    interval,
)
    series1 = [ini_val .+ i * res_incr for i in 0:(horizon - 1)]
    series2 = [ini_val .+ i * res_incr .+ interval_incr for i in 1:horizon]
    startup_data = OrderedDict(
        TIME1 => series1,
        TIME1 + interval => series2,
    )
    return Deterministic(; name = name, data = startup_data, resolution = Hour(1))
end

"Each of `incrs_x`, `incrs_y` is a 3-tuple consisting of a tranche increment plus the same `res_incr` and `interval_incr` as above"
function _make_deterministic_ts(
    name,
    ini_val::PiecewiseStepData,
    incrs_x,
    incrs_y,
    horizon,
    interval,
)
    (tranche_incr_x, res_incr_x, interval_incr_x) = incrs_x
    (tranche_incr_y, res_incr_y, interval_incr_y) = incrs_y

    # Perturb the baseline curves by the tranche increments
    xs1, ys1 = deepcopy(get_x_coords(ini_val)), deepcopy(get_y_coords(ini_val))
    xs1 .+= [i * tranche_incr_x for i in 0:(length(xs1) - 1)]
    ys1 .+= [i * tranche_incr_y for i in 0:(length(ys1) - 1)]
    xs2, ys2 = deepcopy(xs1), deepcopy(ys1)

    # Extend the baselines into time series, applying the resolution and interval increments
    xs1 = [xs1 .+ i * res_incr_x for i in 0:(horizon - 1)]
    xs2 = [xs2 .+ i * res_incr_x .+ interval_incr_x for i in 1:horizon]
    ys1 = [ys1 .+ i * res_incr_y for i in 0:(horizon - 1)]
    ys2 = [ys2 .+ i * res_incr_y .+ interval_incr_y for i in 1:horizon]

    startup_data = OrderedDict(
        TIME1 => PiecewiseStepData.(xs1, ys1),
        TIME1 + interval => PiecewiseStepData.(xs2, ys2),
    )
    return Deterministic(; name = name, data = startup_data, resolution = Hour(1))
end

"""
Add startup and shutdown time series to a certain component. `with_increments`: whether the
elements should be increasing over time or constant. Version A: designed for
`c_fixed_market_bid_cost`.
"""
function add_startup_shutdown_ts_a!(sys::System, with_increments::Bool)
    res_incr = with_increments ? 0.05 : 0.0
    interval_incr = with_increments ? 0.01 : 0.0
    unit1 = get_component(ThermalStandard, sys, "Test Unit1")
    @assert get_operation_cost(unit1) isa MarketBidCost
    startup_ts_1 = _make_deterministic_ts(
        "start_up",
        (1.0, 1.5, 2.0),
        res_incr,
        interval_incr,
        5,
        Hour(1),
    )
    set_start_up!(sys, unit1, startup_ts_1)
    shutdown_ts_1 =
        _make_deterministic_ts("shut_down", 0.5, res_incr, interval_incr, 5, Hour(1))
    set_shut_down!(sys, unit1, shutdown_ts_1)
    return startup_ts_1, shutdown_ts_1
end

"""
Add startup and shutdown time series to a certain component. `with_increments`: whether the
elements should be increasing over time or constant. Version B: designed for `c_sys5_pglib`.
"""
function add_startup_shutdown_ts_b!(sys::System, with_increments::Bool)
    res_incr = with_increments ? 0.05 : 0.0
    interval_incr = with_increments ? 0.01 : 0.0
    unit1 = get_component(ThermalMultiStart, sys, "115_STEAM_1")
    @assert get_operation_cost(unit1) isa MarketBidCost
    startup_ts_1 = _make_deterministic_ts(
        "start_up",
        (300.0, 450.0, 500.0),
        res_incr,
        interval_incr,
        24,
        Day(1),
    )
    set_start_up!(sys, unit1, startup_ts_1)
    shutdown_ts_1 =
        _make_deterministic_ts("shut_down", 100.0, res_incr, interval_incr, 24, Day(1))
    set_shut_down!(sys, unit1, shutdown_ts_1)
    return startup_ts_1, shutdown_ts_1
end

function load_sys_incr()
    sys = Logging.with_logger(Logging.NullLogger()) do
        build_system(PSITestSystems, "c_fixed_market_bid_cost")  # note we are using the fixed one so we can add time series ourselves
    end
    no_load_to_initial_input!(sys)
    return sys
end

function load_sys_decr()
    sys = Logging.with_logger(Logging.NullLogger()) do
        build_system(PSITestSystems, "c_sys5_il")  # note we are using the fixed one so we can add time series ourselves
    end
    no_load_to_initial_input!(sys)
    return sys
end

SEL_INCR = make_selector(ThermalStandard, "Test Unit1")
SEL_DECR = make_selector(InterruptiblePowerLoad, "IloadBus4")

function build_sys_incr(initial_varies::Bool, breakpoints_vary::Bool, slopes_vary::Bool)
    @assert !breakpoints_vary
    @assert !slopes_vary
    sys = load_sys_incr()
    comp = get_component(SEL_INCR, sys)
    op_cost = get_operation_cost(comp)
    baseline = get_value_curve(
        get_incremental_offer_curves(op_cost)::CostCurve,
    )::PiecewiseIncrementalCurve
    baseline_initial = get_initial_input(baseline)
    baseline_pwl = get_function_data(baseline)

    # primes for easier attribution
    incr_initial = initial_varies ? (0.11, 0.05) : (0.0, 0.0)
    incr_x = breakpoints_vary ? (0.02, 0.07, 0.03) : (0.0, 0.0, 0.0)
    incr_y = slopes_vary ? (0.02, 0.07, 0.03) : (0.0, 0.0, 0.0)

    my_initial_ts = _make_deterministic_ts(
        "initial_input",
        baseline_initial,
        incr_initial...,
        5,
        Hour(1),
    )
    my_pwl_ts =
        _make_deterministic_ts("variable_cost", baseline_pwl, incr_x, incr_y, 5, Hour(1))

    set_incremental_initial_input!(sys, comp, my_initial_ts)
    # set_variable_cost!(sys, comp, my_pwl_ts)  # TODO
    return sys
end

_read_one_value(res_uc, var_name, gentype, unit_name) =
    combine(
        vcat(values(read_variable(res_uc, var_name, gentype))...), unit_name .=> sum)[
        1,
        1,
    ]

function run_generic_mbc_sim(sys::System; multistart::Bool = false)
    template = ProblemTemplate(
        NetworkModel(
            CopperPlatePowerModel;
            duals = [CopperPlateBalanceConstraint],
        ),
    )
    set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
    multistart &&
        set_device_model!(template, ThermalMultiStart, ThermalMultiStartUnitCommitment)
    set_device_model!(template, PowerLoad, StaticPowerLoad)

    model = DecisionModel(
        template,
        sys;
        name = "UC",
        store_variable_names = true,
        optimizer = HiGHS_optimizer,
        system_to_file = false,
    )

    # Test solving the model outside of a Simulation
    model_ = deepcopy(model)
    @test build!(model_; output_dir = test_path) == PSI.ModelBuildStatus.BUILT
    @test solve!(model_) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    models = SimulationModels(;
        decision_models = [
            model,
        ],
    )
    sequence = SimulationSequence(;
        models = models,
        feedforwards = Dict(
        ),
        ini_cond_chronology = InterProblemChronology(),
    )

    sim = Simulation(;
        name = "compact_sim",
        steps = 2,
        models = models,
        sequence = sequence,
        initial_time = TIME1,
        simulation_folder = mktempdir(),
    )

    build!(sim; serialize = false)
    execute!(sim; enable_progress_bar = true)

    sim_res = SimulationResults(sim)
    res_uc = get_decision_problem_results(sim_res, "UC")
    return model_, model, res_uc
end

"Run a simple simulation with the system and return information useful for testing time-varying startup and shutdown functionality"
function run_startup_shutdown_sim(sys::System; multistart::Bool = false)
    model_, model, res_uc = run_generic_mbc_sim(sys; multistart = multistart)

    # Test correctness of written shutdown cost parameters
    # TODO test startup too once we are able to write those
    gentype = multistart ? ThermalMultiStart : ThermalStandard
    genname = multistart ? "115_STEAM_1" : "Test Unit1"
    sh_uc = read_parameter(res_uc, PSI.ShutdownCostParameter, gentype)
    for (step_dt, step_df) in pairs(sh_uc)
        for gen_name in names(DataFrames.select(step_df, Not(:DateTime)))
            comp = get_component(gentype, sys, gen_name)
            fc_comp =
                get_shut_down(comp, PSY.get_operation_cost(comp); start_time = step_dt)
            @test all(step_df[!, :DateTime] .== TimeSeries.timestamp(fc_comp))
            @test all(isapprox.(step_df[!, gen_name], TimeSeries.values(fc_comp)))
        end
    end

    switches = if multistart
        (
            _read_one_value(res_uc, PSI.HotStartVariable, gentype, genname),
            _read_one_value(res_uc, PSI.WarmStartVariable, gentype, genname),
            _read_one_value(res_uc, PSI.ColdStartVariable, gentype, genname),
            _read_one_value(res_uc, PSI.StopVariable, gentype, genname),
        )
    else
        (
            _read_one_value(res_uc, PSI.StartVariable, gentype, genname),
            _read_one_value(res_uc, PSI.StopVariable, gentype, genname),
        )
    end
    return model_, model, res_uc, switches
end

"Run a simple simulation with the system and return information useful for testing time-varying startup and shutdown functionality"
function run_mbc_sim(sys::System; is_decremental::Bool = false)
    model_, model, res_uc = run_generic_mbc_sim(sys)

    ii_uc = read_parameter(res_uc, PSI.IncrementalCostAtMinParameter, ThermalStandard)
    for (step_dt, step_df) in pairs(ii_uc)
        for gen_name in names(DataFrames.select(step_df, Not(:DateTime)))
            comp = get_component(ThermalStandard, sys, gen_name)
            ii_comp = get_incremental_initial_input(
                comp,
                PSY.get_operation_cost(comp);
                start_time = step_dt,
            )
            @test all(step_df[!, :DateTime] .== TimeSeries.timestamp(ii_comp))
            @test all(isapprox.(step_df[!, gen_name], TimeSeries.values(ii_comp)))
        end
    end

    # NOTE this could be rewritten nicely using PowerAnalytics
    comp = get_component(is_decremental ? SEL_DECR : SEL_INCR, sys)
    gentype, genname = typeof(comp), get_name(comp)
    switches = (
        _read_one_value(res_uc, PSI.OnVariable, gentype, genname)
    )
    return model_, model, res_uc, switches
end

"Read the relevant startup variables: no multistart case"
_read_start_vars(::Val{false}, res_uc::PSI.SimulationProblemResults) =
    read_variable(res_uc, PSI.StartVariable, ThermalStandard)

"Read the relevant startup variables: yes multistart case"
function _read_start_vars(::Val{true}, res_uc::PSI.SimulationProblemResults)
    hot_vars = read_variable(res_uc, PSI.HotStartVariable, ThermalMultiStart)
    warm_vars = read_variable(res_uc, PSI.WarmStartVariable, ThermalMultiStart)
    cold_vars = read_variable(res_uc, PSI.ColdStartVariable, ThermalMultiStart)

    @assert all(keys(hot_vars) .== keys(warm_vars))
    @assert all(keys(hot_vars) .== keys(cold_vars))
    @assert all(
        all(hot_vars[k][!, :DateTime] .== warm_vars[k][!, :DateTime]) for
        k in keys(hot_vars)
    )
    @assert all(
        all(hot_vars[k][!, :DateTime] .== cold_vars[k][!, :DateTime]) for
        k in keys(hot_vars)
    )
    # Make a dictionary of combined dataframes where the entries are (hot, warm, cold)
    combined_vars = Dict(
        k => DataFrame(
            "DateTime" => hot_vars[k][!, :DateTime],
            [
                gen_name => [
                    (hot, warm, cold) for (hot, warm, cold) in zip(
                        hot_vars[k][!, gen_name],
                        warm_vars[k][!, gen_name],
                        cold_vars[k][!, gen_name],
                    )
                ] for gen_name in names(select(hot_vars[k], Not(:DateTime)))
            ]...,
        ) for k in keys(hot_vars)
    )
    return combined_vars
end

"""
Read startup and shutdown cost time series from a `System` and multiply by relevant start
and stop variables in the `SimulationProblemResults` to determine the cost that should have
been incurred by time-varying `MarketBidCost` startup and shutdown costs. Must run
separately for multistart vs. not.
"""
function cost_due_to_time_varying_startup_shutdown(
    sys::System,
    res_uc::PSI.SimulationProblemResults;
    multistart = false,
)
    gentype = multistart ? ThermalMultiStart : ThermalStandard
    start_vars = _read_start_vars(Val(multistart), res_uc)
    stop_vars = read_variable(res_uc, PSI.StopVariable, gentype)
    result = SortedDict{DateTime, DataFrame}()
    @assert all(keys(start_vars) .== keys(stop_vars))
    for step_dt in keys(start_vars)
        start_df = start_vars[step_dt]
        stop_df = stop_vars[step_dt]
        @assert names(start_df) == names(stop_df)
        @assert start_df[!, :DateTime] == stop_df[!, :DateTime]
        result[step_dt] = DataFrame(:DateTime => start_df[!, :DateTime])
        for gen_name in names(DataFrames.select(start_df, Not(:DateTime)))
            comp = get_component(gentype, sys, gen_name)
            cost = PSY.get_operation_cost(comp)
            (cost isa PSY.MarketBidCost) || continue
            PSI.is_time_variant(get_start_up(cost)) || continue
            @assert PSI.is_time_variant(get_shut_down(cost))
            startup_ts = get_start_up(comp, cost; start_time = step_dt)
            shutdown_ts = get_shut_down(comp, cost; start_time = step_dt)

            @assert all(start_df[!, :DateTime] .== TimeSeries.timestamp(startup_ts))
            @assert all(start_df[!, :DateTime] .== TimeSeries.timestamp(shutdown_ts))
            startup_values = if multistart
                TimeSeries.values(startup_ts)
            else
                getproperty.(TimeSeries.values(startup_ts), :hot)
            end
            result[step_dt][!, gen_name] =
                LinearAlgebra.dot.(start_df[!, gen_name], startup_values) .+
                stop_df[!, gen_name] .* TimeSeries.values(shutdown_ts)
        end
    end
    return result
end

function cost_due_to_time_varying_mbc(
    sys::System,
    res_uc::PSI.SimulationProblemResults;
    is_decremental = false,
)
    is_decremental && throw(IS.NotImplementedError("TODO implement for decremental"))
    gentype = ThermalStandard
    on_vars = read_variable(res_uc, PSI.OnVariable, gentype)
    result = SortedDict{DateTime, DataFrame}()
    for step_dt in keys(on_vars)
        on_df = on_vars[step_dt]
        result[step_dt] = DataFrame(:DateTime => on_df[!, :DateTime])
        for gen_name in names(DataFrames.select(on_df, Not(:DateTime)))
            comp = get_component(gentype, sys, gen_name)
            cost = PSY.get_operation_cost(comp)
            (cost isa MarketBidCost) || continue
            PSI.is_time_variant(get_incremental_initial_input(cost)) || continue
            ii_ts = get_incremental_initial_input(comp, cost; start_time = step_dt)
            @assert all(on_df[!, :DateTime] .== TimeSeries.timestamp(ii_ts))
            result[step_dt][!, gen_name] = on_df[!, gen_name] .* TimeSeries.values(ii_ts)
        end
    end
    return result
end

"Modifies `c_sys5_pglib` to facilitate the exercise of the multi-start capability in a test simulation"
function modify_sys_for_multistart!(sys::System, load_mult, therm_mult)
    for load in get_components(PowerLoad, sys)
        set_max_active_power!(load, get_max_active_power(load) * load_mult)
    end
    for therm in get_components(ThermalStandard, sys)
        op_cost = get_operation_cost(therm)
        prop = get_proportional_term(get_value_curve(get_variable(op_cost)))
        set_variable!(op_cost, CostCurve(LinearCurve(prop * therm_mult)))
    end
end

function create_multistart_sys(with_increments::Bool, load_mult, therm_mult)
    c_sys5_pglib = Logging.with_logger(Logging.NullLogger()) do
        PSB.build_system(PSITestSystems, "c_sys5_pglib")
    end
    no_load_to_initial_input!(c_sys5_pglib)
    modify_sys_for_multistart!(c_sys5_pglib, load_mult, therm_mult)
    sel = make_selector(ThermalMultiStart, "115_STEAM_1")
    ms_comp = get_component(sel, c_sys5_pglib)
    old_op = get_operation_cost(ms_comp)
    old_ic = IncrementalCurve(get_value_curve(get_variable(old_op)))
    new_ii = get_initial_input(old_ic) + get_fixed(old_op)
    new_ic = IncrementalCurve(get_function_data(old_ic), new_ii, nothing)
    set_operation_cost!(
        ms_comp,
        MarketBidCost(;
            no_load_cost = nothing,
            start_up = get_start_up(old_op),
            shut_down = get_shut_down(old_op),
            incremental_offer_curves = CostCurve(new_ic),
        ),
    )
    add_startup_shutdown_ts_b!(c_sys5_pglib, with_increments)
    return c_sys5_pglib
end

# See run_startup_shutdown_obj_fun_test for explanation
function _obj_fun_test_helper(ground_truth_1, ground_truth_2, res_uc1, res_uc2)
    @assert all(keys(ground_truth_1) .== keys(ground_truth_2))

    # Sum across components, time periods to get one value per step
    total1 = [
        only(sum(eachcol(combine(val, Not(:DateTime) .=> sum)))) for
        val in values(ground_truth_1)
    ]
    total2 = [
        only(sum(eachcol(combine(val, Not(:DateTime) .=> sum)))) for
        val in values(ground_truth_2)
    ]
    ground_truth = total2 .- total1  # How much did the cost increase between simulation 1 and simulation 2 for each step

    obj1 = PSI.read_optimizer_stats(res_uc1)[!, "objective_value"]
    obj2 = PSI.read_optimizer_stats(res_uc2)[!, "objective_value"]
    obj_diff = obj2 .- obj1

    @test all(isapprox.(obj_diff, ground_truth; atol = 0.0001))
end

"""
The methodology here is: run a simulation where the startup and shutdown time series have
constant values through time, then run a nearly identical simulation where the values vary
very slightly through time, not enough to affect the decisions but enough to affect the
objective value, then compare the size of the objective value change to an expectation
computed manually.
"""
function run_startup_shutdown_obj_fun_test(sys1, sys2; multistart::Bool = false)
    model1_, model1, res_uc1, switches1 =
        run_startup_shutdown_sim(sys1; multistart = multistart)
    model2_, model2, res_uc2, switches2 =
        run_startup_shutdown_sim(sys2; multistart = multistart)

    ground_truth_1 =
        cost_due_to_time_varying_startup_shutdown(sys1, res_uc1; multistart = multistart)
    ground_truth_2 =
        cost_due_to_time_varying_startup_shutdown(sys2, res_uc2; multistart = multistart)

    _obj_fun_test_helper(ground_truth_1, ground_truth_2, res_uc1, res_uc2)
    return switches1, switches2
end

# Same methodology as run_startup_shutdown_obj_fun_test
function run_mbc_obj_fun_test(sys1, sys2; is_decremental::Bool = false)
    model1_, model1, res_uc1, switches1 = run_mbc_sim(sys1; is_decremental = is_decremental)
    model2_, model2, res_uc2, switches2 = run_mbc_sim(sys2; is_decremental = is_decremental)

    ground_truth_1 =
        cost_due_to_time_varying_mbc(sys1, res_uc1; is_decremental = is_decremental)
    ground_truth_2 =
        cost_due_to_time_varying_mbc(sys2, res_uc2; is_decremental = is_decremental)

    _obj_fun_test_helper(ground_truth_1, ground_truth_2, res_uc1, res_uc2)
    return switches1, switches2
end

@testset "MarketBidCost with time series startup and shutdown, ThermalStandard" begin
    # Test that constant time series has the same objective value as no time series
    sys0 = PSB.build_system(PSITestSystems, "c_fixed_market_bid_cost")
    no_load_to_initial_input!(sys0)
    cost = get_operation_cost(get_component(ThermalStandard, sys0, "Test Unit1"))
    set_start_up!(cost, (hot = 1.0, warm = 1.5, cold = 2.0))
    set_shut_down!(cost, 0.5)
    sys1 = PSB.build_system(PSITestSystems, "c_fixed_market_bid_cost")
    no_load_to_initial_input!(sys1)
    add_startup_shutdown_ts_a!(sys1, false)
    _, _, res_uc0 = run_generic_mbc_sim(sys0; multistart = false)
    _, _, res_uc1 = run_generic_mbc_sim(sys1; multistart = false)
    obj_val_0 = PSI.read_optimizer_stats(res_uc0)[!, "objective_value"]
    obj_val_1 = PSI.read_optimizer_stats(res_uc1)[!, "objective_value"]
    @test isapprox(obj_val_0, obj_val_1; atol = 0.0001)

    # Test that perturbing the time series perturbs the objective value as expected
    sys2 = PSB.build_system(PSITestSystems, "c_fixed_market_bid_cost")
    no_load_to_initial_input!(sys2)
    add_startup_shutdown_ts_a!(sys2, true)
    (switches1, switches2) = run_startup_shutdown_obj_fun_test(sys1, sys2)
    @test all(isapprox.(switches1, switches2))

    # Make sure our tests included sufficent startups and shutdowns
    @assert all(>=(1).(switches1))
end

@testset "MarketBidCost with time series startup and shutdown, ThermalMultiStart" begin
    # Scenario 1: hot and warm starts
    c_sys5_pglib1 = create_multistart_sys(false, 1.0, 7.5)
    c_sys5_pglib2 = create_multistart_sys(true, 1.0, 7.5)
    (switches1, switches2) =
        run_startup_shutdown_obj_fun_test(c_sys5_pglib1, c_sys5_pglib2; multistart = true)
    @test all(isapprox.(switches1, switches2))

    # Scenario 2: hot and cold starts
    c_sys5_pglib1 = create_multistart_sys(false, 1.05, 7.5)
    c_sys5_pglib2 = create_multistart_sys(true, 1.05, 7.5)
    (switches1_2, switches2_2) =
        run_startup_shutdown_obj_fun_test(c_sys5_pglib1, c_sys5_pglib2; multistart = true)
    @test all(isapprox.(switches1_2, switches2_2))

    # Make sure our tests included all types of startups and shutdowns
    @assert all(>=(1).(switches1 .+ switches1_2))
end

@testset "MarketBidCost incremental with time series min gen cost" begin
    baseline = build_sys_incr(false, false, false)
    plus_initial = build_sys_incr(true, false, false)

    switches1, switches2 = run_mbc_obj_fun_test(baseline, plus_initial)
    @test all(isapprox.(switches1, switches2))
    @assert all(>=(1).(switches1))

    # TODO test validate_initial_input_time_series warnings/errors
end
