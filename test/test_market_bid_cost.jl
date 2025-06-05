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

"Set the no_load_cost to `nothing` and the initial_input to the old no_load_cost. Not designed for time series"
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
) = no_load_to_initial_input!.(get_components(sel, sys))

# TODO this is part of the 1318 stopgap
"Set all MBC thermal unit min active powers to their min breakpoints"
function adjust_min_power!(sys)
    for comp in get_components(Union{ThermalStandard, ThermalMultiStart}, sys)
        op_cost = get_operation_cost(comp)
        op_cost isa MarketBidCost || continue
        cost_curve = get_incremental_offer_curves(op_cost)::CostCurve
        baseline = get_value_curve(cost_curve)::PiecewiseIncrementalCurve
        x_coords = get_x_coords(get_function_data(baseline))
        with_units_base(sys, UnitSystem.NATURAL_UNITS) do
            set_active_power_limits!(comp, (min = first(x_coords), max = last(x_coords)))
        end
    end
end

function load_and_fix_system(args...)
    sys = Logging.with_logger(Logging.NullLogger()) do
        build_system(args...)
    end
    no_load_to_initial_input!(sys)
    adjust_min_power!(sys)
    return sys
end

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

# Layer of indirection to upgrade problem results to look like simulation results
_maybe_upgrade_to_dict(in::AbstractDict) = in
_maybe_upgrade_to_dict(in::DataFrame) =
    SortedDict{DateTime, DataFrame}(first(in[!, :DateTime]) => in)

read_variable_dict(
    res_uc::IS.Results,
    var_name::Type{<:PSI.VariableType},
    comp_type::Type{<:PSY.Component},
) =
    _maybe_upgrade_to_dict(read_variable(res_uc, var_name, comp_type))
read_parameter_dict(
    res_uc::IS.Results,
    par_name::Type{<:PSI.ParameterType},
    comp_type::Type{<:PSY.Component},
) =
    _maybe_upgrade_to_dict(read_parameter(res_uc, par_name, comp_type))

function load_sys_incr()
    # note we are using the fixed one so we can add time series ourselves
    sys = load_and_fix_system(PSITestSystems, "c_fixed_market_bid_cost")
    tweak_system!(sys, 1.05, 1.0, 1.0)
    # TODO do this better if it's sticking around
    get_component(
        ThermalStandard,
        sys,
        "Test Unit2",
    ).operation_cost.incremental_offer_curves.value_curve.function_data.y_coords[1] *= 0.9
    return sys
end

function load_sys_decr()
    sys = load_and_fix_system(PSITestSystems, "c_sys5_il")
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
        vcat(values(read_variable_dict(res_uc, var_name, gentype))...),
        unit_name .=> sum,
    )[
        1,
        1,
    ]

function build_generic_mbc_model(sys::System; multistart::Bool = false)
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
    return model
end

function run_generic_mbc_prob(sys::System; multistart::Bool = false)
    model = build_generic_mbc_model(sys; multistart = multistart)
    @test build!(model; output_dir = test_path) == PSI.ModelBuildStatus.BUILT
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
    res = OptimizationProblemResults(model)
    return model, res
end

function run_generic_mbc_sim(sys::System; multistart::Bool = false)
    model = build_generic_mbc_model(sys; multistart = multistart)
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
    return model, res_uc
end

"""
Run a simple simulation with the system and return information useful for testing
time-varying startup and shutdown functionality. Pass `simulation = false` to use a single
decision model, `true` for a full simulation.
"""
function run_startup_shutdown_test(sys::System; multistart::Bool = false, simulation = true)
    model, res = if simulation
        run_generic_mbc_sim(sys; multistart = multistart)
    else
        run_generic_mbc_prob(sys; multistart = multistart)
    end

    # Test correctness of written shutdown cost parameters
    # TODO test startup too once we are able to write those
    gentype = multistart ? ThermalMultiStart : ThermalStandard
    genname = multistart ? "115_STEAM_1" : "Test Unit1"
    sh_param = read_parameter_dict(res, PSI.ShutdownCostParameter, gentype)
    for (step_dt, step_df) in pairs(sh_param)
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
            _read_one_value(res, PSI.HotStartVariable, gentype, genname),
            _read_one_value(res, PSI.WarmStartVariable, gentype, genname),
            _read_one_value(res, PSI.ColdStartVariable, gentype, genname),
            _read_one_value(res, PSI.StopVariable, gentype, genname),
        )
    else
        (
            _read_one_value(res, PSI.StartVariable, gentype, genname),
            _read_one_value(res, PSI.StopVariable, gentype, genname),
        )
    end
    return model, res, switches
end

"""
Run a simple simulation with the system and return information useful for testing
time-varying startup and shutdown functionality.  Pass `simulation = false` to use a single
decision model, `true` for a full simulation.
"""
function run_mbc_sim(sys::System; is_decremental::Bool = false, simulation = true)
    model, res = if simulation
        run_generic_mbc_sim(sys)
    else
        run_generic_mbc_prob(sys)
    end

    # TODO test slopes, breakpoints too once we are able to write those 
    ii_param = read_parameter_dict(res, PSI.IncrementalCostAtMinParameter, ThermalStandard)
    for (step_dt, step_df) in pairs(ii_param)
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
        _read_one_value(res, PSI.OnVariable, gentype, genname)
    )
    return model, res, switches
end

"Read the relevant startup variables: no multistart case"
_read_start_vars(::Val{false}, res::IS.Results) =
    read_variable_dict(res, PSI.StartVariable, ThermalStandard)

"Read the relevant startup variables: yes multistart case"
function _read_start_vars(::Val{true}, res::IS.Results)
    hot_vars =
        read_variable_dict(res, PSI.HotStartVariable, ThermalMultiStart)
    warm_vars =
        read_variable_dict(res, PSI.WarmStartVariable, ThermalMultiStart)
    cold_vars =
        read_variable_dict(res, PSI.ColdStartVariable, ThermalMultiStart)

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
and stop variables in the `IS.Results` to determine the cost that should have been incurred
by time-varying `MarketBidCost` startup and shutdown costs. Must run separately for
multistart vs. not.
"""
function cost_due_to_time_varying_startup_shutdown(
    sys::System,
    res::IS.Results;
    multistart = false,
)
    gentype = multistart ? ThermalMultiStart : ThermalStandard
    start_vars = _read_start_vars(Val(multistart), res)
    stop_vars = read_variable_dict(res, PSI.StopVariable, gentype)
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
    res_uc::IS.Results;
    is_decremental = false,
)
    is_decremental && throw(IS.NotImplementedError("TODO implement for decremental"))
    gentype = ThermalStandard
    on_vars = read_variable_dict(res_uc, PSI.OnVariable, gentype)
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

"""
Helper function to tweak load powers, non-MBC generator powers, and non-MBC generator costs
to exercise the generators we want to test
"""
function tweak_system!(sys::System, load_pow_mult, therm_pow_mult, therm_price_mult)
    for load in get_components(PowerLoad, sys)
        set_max_active_power!(load, get_max_active_power(load) * load_pow_mult)
    end
    for therm in get_components(ThermalStandard, sys)
        op_cost = get_operation_cost(therm)
        op_cost isa MarketBidCost && continue
        old_limits = therm.active_power_limits
        therm.active_power_limits =
            (min = old_limits.min, max = old_limits.max * therm_pow_mult)
        prop = get_proportional_term(get_value_curve(get_variable(op_cost)))
        set_variable!(op_cost, CostCurve(LinearCurve(prop * therm_price_mult)))
    end
end

function create_multistart_sys(with_increments::Bool, load_mult, therm_mult)
    c_sys5_pglib = load_and_fix_system(PSITestSystems, "c_sys5_pglib")
    tweak_system!(c_sys5_pglib, load_mult, 1.0, therm_mult)
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
    ground_truth_diff = total2 .- total1  # How much did the cost increase between simulation 1 and simulation 2 for each step

    obj1 = PSI.read_optimizer_stats(res_uc1)[!, "objective_value"]
    obj2 = PSI.read_optimizer_stats(res_uc2)[!, "objective_value"]
    obj_diff = obj2 .- obj1

    # Make sure there is some real difference between the two scenarios
    @assert !any(isapprox.(ground_truth_diff, 0.0; atol = 0.0001))
    # Make sure the difference is reflected correctly in the objective value
    @test all(isapprox.(obj_diff, ground_truth_diff; atol = 0.0001))
end

"""
The methodology here is: run a model or simulation where the startup and shutdown time
series have constant values through time, then run a nearly identical model/simulation where
the values vary very slightly through time, not enough to affect the decisions but enough to
affect the objective value, then compare the size of the objective value change to an
expectation computed manually.

Pass `simulation = false` to use a single decision model, `true` for a full simulation.
"""
function run_startup_shutdown_obj_fun_test(
    sys1,
    sys2;
    multistart::Bool = false,
    simulation = true,
)
    _, res1, switches1 =
        run_startup_shutdown_test(sys1; multistart = multistart, simulation = simulation)
    _, res2, switches2 =
        run_startup_shutdown_test(sys2; multistart = multistart, simulation = simulation)

    ground_truth_1 =
        cost_due_to_time_varying_startup_shutdown(sys1, res1; multistart = multistart)
    ground_truth_2 =
        cost_due_to_time_varying_startup_shutdown(sys2, res2; multistart = multistart)

    _obj_fun_test_helper(ground_truth_1, ground_truth_2, res1, res2)
    return switches1, switches2
end

# See run_startup_shutdown_obj_fun_test for explanation
function run_mbc_obj_fun_test(sys1, sys2; is_decremental::Bool = false, simulation = true)
    _, res1, switches1 =
        run_mbc_sim(sys1; is_decremental = is_decremental, simulation = simulation)
    _, res2, switches2 =
        run_mbc_sim(sys2; is_decremental = is_decremental, simulation = simulation)

    ground_truth_1 =
        cost_due_to_time_varying_mbc(sys1, res1; is_decremental = is_decremental)
    ground_truth_2 =
        cost_due_to_time_varying_mbc(sys2, res2; is_decremental = is_decremental)

    _obj_fun_test_helper(ground_truth_1, ground_truth_2, res1, res2)
    return switches1, switches2
end

function tweak_for_startup_shutdown!(sys::System)
    tweak_system!(sys::System, 0.8, 1.0, 1.0)
end

@testset "MarketBidCost with time series startup and shutdown, ThermalStandard" begin
    # Test that constant time series has the same objective value as no time series
    sys0 = load_and_fix_system(PSITestSystems, "c_fixed_market_bid_cost")
    tweak_for_startup_shutdown!(sys0)
    cost = get_operation_cost(get_component(ThermalStandard, sys0, "Test Unit1"))
    set_start_up!(cost, (hot = 1.0, warm = 1.5, cold = 2.0))
    set_shut_down!(cost, 0.5)
    sys1 = load_and_fix_system(PSITestSystems, "c_fixed_market_bid_cost")
    tweak_for_startup_shutdown!(sys1)
    add_startup_shutdown_ts_a!(sys1, false)
    for runner in (run_generic_mbc_prob, run_generic_mbc_sim)  # test with both a single problem and a full simulation
        _, res0 = runner(sys0; multistart = false)
        _, res1 = runner(sys1; multistart = false)
        obj_val_0 = PSI.read_optimizer_stats(res0)[!, "objective_value"]
        obj_val_1 = PSI.read_optimizer_stats(res1)[!, "objective_value"]
        @test isapprox(obj_val_0, obj_val_1; atol = 0.0001)
    end

    # Test that perturbing the time series perturbs the objective value as expected
    sys2 = load_and_fix_system(PSITestSystems, "c_fixed_market_bid_cost")
    tweak_for_startup_shutdown!(sys2)
    add_startup_shutdown_ts_a!(sys2, true)

    for use_simulation in (false, true)
        (switches1, switches2) =
            run_startup_shutdown_obj_fun_test(sys1, sys2; simulation = use_simulation)
        @test all(isapprox.(switches1, switches2))
        # Make sure our tests included sufficent startups and shutdowns
        @assert all(>=(1).(switches1))
    end
end

@testset "MarketBidCost with time series startup and shutdown, ThermalMultiStart" begin
    # Scenario 1: hot and warm starts
    c_sys5_pglib1a = create_multistart_sys(false, 1.0, 7.5)
    c_sys5_pglib2a = create_multistart_sys(true, 1.0, 7.5)

    # Scenario 2: hot and cold starts
    c_sys5_pglib1b = create_multistart_sys(false, 1.05, 7.5)
    c_sys5_pglib2b = create_multistart_sys(true, 1.05, 7.5)

    for use_simulation in (false, true)
        (switches1, switches2) = run_startup_shutdown_obj_fun_test(
            c_sys5_pglib1a,
            c_sys5_pglib2a;
            multistart = true,
            simulation = use_simulation,
        )
        @test all(isapprox.(switches1, switches2))
        # NOTE not all of the switches here are >= 1, we'll do another scenario such that we get full switch coverage across both of them:

        (switches1_2, switches2_2) = run_startup_shutdown_obj_fun_test(
            c_sys5_pglib1b,
            c_sys5_pglib2b;
            multistart = true,
            simulation = use_simulation,
        )
        @test all(isapprox.(switches1_2, switches2_2))
        # Make sure our tests included all types of startups and shutdowns
        @assert all(>=(1).(switches1 .+ switches1_2))
    end
end

@testset "MarketBidCost incremental with time series min gen cost" begin
    baseline = build_sys_incr(false, false, false)
    plus_initial = build_sys_incr(true, false, false)

    for use_simulation in (false, true)
        switches1, switches2 =
            run_mbc_obj_fun_test(baseline, plus_initial; simulation = use_simulation)
        @test all(isapprox.(switches1, switches2))
        @assert all(>=(1).(switches1))
    end

    # TODO test validate_initial_input_time_series warnings/errors
end
