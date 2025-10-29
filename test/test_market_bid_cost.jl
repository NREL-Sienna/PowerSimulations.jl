test_path = mktempdir()
const TIME1 = DateTime("2024-01-01T00:00:00")
const SEL_INCR = make_selector(ThermalStandard, "Test Unit1")
const SEL_DECR = make_selector(InterruptiblePowerLoad, "Bus1_interruptible")
const SEL_MULTISTART = make_selector(ThermalMultiStart, "115_STEAM_1")
const DEFAULT_FORMULATIONS =
    Dict{Type{<:PSY.Device}, Type{<:PSI.AbstractDeviceFormulation}}(
        ThermalStandard => ThermalBasicUnitCommitment,
        PowerLoad => StaticPowerLoad,
        InterruptiblePowerLoad => PowerLoadInterruption,
        RenewableDispatch => RenewableFullDispatch,
        HydroDispatch => HydroCommitmentRunOfRiver,
        EnergyReservoirStorage => StorageDispatchWithReserves,
    )

# debugging code for inspecting objective functions -- ignore
# TODO LK group by folders.
const DOWNLOADS = joinpath(homedir(), "Downloads")
function format_objective_function_file(filepath::String)
    if !isfile(filepath)
        println("Error: File '$filepath' does not exist.")
        exit(1)
    end

    try
        content = read(filepath, String)
        content = replace(content, "+" => "+\n")
        content = replace(content, "-" => "-\n")
        write(filepath, content)
    catch e
        println("Error processing file '$filepath': $e")
        exit(1)
    end
end

function save_objective_function(model::DecisionModel, filepath::String)
    open(filepath, "w") do file
        println(file, "invariant_terms:")
        println(file, model.internal.container.objective_function.invariant_terms)
        println(file, "variant_terms:")
        println(file, model.internal.container.objective_function.variant_terms)
    end
    format_objective_function_file(filepath)
end

function save_constraints(model::DecisionModel, filepath::String)
    open(filepath, "w") do file
        for (k, v) in model.internal.container.constraints
            println(file, "Constraint Type: $(k)")
            println(file, v)
        end
    end
end
# end debugging code

function set_formulations!(template::ProblemTemplate,
    sys::PSY.System,
    device_to_formulation::Dict{Type{<:PSY.Device}, Type{<:PSI.AbstractDeviceFormulation}},
)
    for (device, formulation) in device_to_formulation
        if !isempty(get_components(device, sys))
            set_device_model!(template, device, formulation)
        end
    end
    for (device, formulation) in DEFAULT_FORMULATIONS
        if !haskey(device_to_formulation, device) && !isempty(get_components(device, sys))
            set_device_model!(template, device, formulation)
        end
    end
end

function test_market_bid_cost_models(sys::PSY.System,
    test_unit::PSY.Component,
    my_no_load::Float64,
    my_initial_input::Float64;
    skip_setting = false,
    device_to_formulation = Dict{
        Type{<:PSY.Device},
        Type{<:PSI.AbstractDeviceFormulation},
    }(),
    save_obj_fcn = false,
)
    fcn_data = get_function_data(
        get_value_curve(
            get_incremental_offer_curves(get_operation_cost(test_unit)),
        ),
    )
    if !skip_setting
        new_vc = PiecewiseIncrementalCurve(fcn_data, my_initial_input, my_no_load)
        set_incremental_offer_curves!(
            get_operation_cost(test_unit),
            CostCurve(new_vc),
        )
    end
    set_no_load_cost!(get_operation_cost(test_unit), my_no_load)
    template = ProblemTemplate(NetworkModel(CopperPlatePowerModel))

    set_formulations!(
        template,
        sys,
        device_to_formulation,
    )

    model = DecisionModel(
        template,
        sys;
        name = "UC_test_mbc",
        optimizer = HiGHS_optimizer_small_gap,
        system_to_file = false,
        optimizer_solve_log_print = true,
        store_variable_names = true,
    )

    @test build!(model; output_dir = test_path) == PSI.ModelBuildStatus.BUILT
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
    if save_obj_fcn
        save_loc = joinpath(DOWNLOADS, "thermal_vs_renewable")
        @assert isdir(save_loc)

        save_objective_function(
            model,
            joinpath(
                save_loc,
                "objective_function_$(get_name(sys))_$(get_name(test_unit)).txt",
            ),
        )
        save_constraints(
            model,
            joinpath(save_loc, "constraints_$(get_name(sys))_$(get_name(test_unit)).txt"),
        )
    end

    return OptimizationProblemResults(model)
end

function verify_market_bid_cost_models(sys::PSY.System,
    test_unit::PSY.Component,
    cost_reference::Float64,
    no_load_cost::Float64,
    my_initial_input::Float64,
)
    results = test_market_bid_cost_models(
        sys,
        test_unit,
        no_load_cost,
        my_initial_input,
    )
    expr = read_expression(results, "ProductionCostExpression__ThermalStandard")
    component_df = @rsubset(expr, :name == get_name(test_unit))
    var_unit_cost =
        only(@combine(component_df, :var_unit_cost = sum(:value)).var_unit_cost)
    unit_cost_due_to_initial =
        nrow(@rsubset(component_df, :value != 0)) * my_initial_input
    @test isapprox(
        var_unit_cost,
        cost_reference + unit_cost_due_to_initial;
        atol = 1,
    )
end

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
            verify_market_bid_cost_models(
                sys,
                unit1,
                cost_reference,
                my_no_load,
                my_initial_input,
            )
        end
    end
end

function transfer_mbc_time_series!(
    new_comp::PSY.Device,
    old_comp::PSY.Device,
    new_sys::PSY.System,
)
    mbc = deepcopy(get_operation_cost(old_comp))
    @assert mbc isa PSY.MarketBidCost
    for field in fieldnames(PSY.MarketBidCost)
        val = getfield(mbc, field)
        if val isa IS.TimeSeriesKey
            ts = PSY.get_time_series(old_comp, val)
            new_ts_key = add_time_series!(new_sys, new_comp, deepcopy(ts))
            setfield!(mbc, field, new_ts_key)
        end
    end
    set_operation_cost!(new_comp, mbc)
    return
end

function replace_with_renewable!(
    sys::PSY.System,
    unit1::PSY.Generator;
    use_thermal_max_power = false,
    magnitude = 1.0,
    random_variation = 0.1,
)
    rg1 = PSY.RenewableDispatch(;
        name = "RG1",
        available = true,
        bus = get_bus(unit1),
        active_power = get_active_power(unit1),
        reactive_power = get_reactive_power(unit1),
        rating = get_rating(unit1),
        prime_mover_type = PSY.PrimeMovers.PVe,
        reactive_power_limits = get_reactive_power_limits(unit1),
        power_factor = 0.9,
        # the start up, shunt down, and no-load cost of renewables should be zero,
        # but we'll use the unit's operation cost as-is for simplicity.
        operation_cost = deepcopy(get_operation_cost(unit1)),
        base_power = get_base_power(unit1),
    )
    add_component!(sys, rg1)
    transfer_mbc_time_series!(rg1, unit1, sys)
    remove_component!(sys, unit1)

    # add a max_active_power time series to the component
    load = first(PSY.get_components(PSY.PowerLoad, sys))
    load_ts = get_time_series(Deterministic, load, "max_active_power")
    num_windows = length(get_data(load_ts))
    num_forecast_steps =
        floor(Int, get_horizon(load_ts) / get_interval(load_ts))
    total_steps = num_windows + num_forecast_steps - 1
    dates = range(
        get_initial_timestamp(load_ts);
        step = get_interval(load_ts),
        length = total_steps,
    )
    if use_thermal_max_power
        rg_data = fill(get_active_power_limits(unit1).max, total_steps)
    else
        rg_data = magnitude .* ones(total_steps) .+ random_variation .* rand(total_steps)
    end
    rg_ts = SingleTimeSeries("max_active_power", TimeArray(dates, rg_data))
    add_time_series!(sys, rg1, rg_ts)
    transform_single_time_series!(
        sys,
        get_horizon(load_ts),
        get_interval(load_ts),
    )
end

@testset "Test Renewable Dispatch MarketBidCost models" begin
    test_cases = [
        ("Base case", "fixed_market_bid_cost", 18487.236, 30.0, 30.0),
        ("Greater initial input, no load", "fixed_market_bid_cost", 18487.236, 31.0, 31.0),
        ("Greater initial input only", "fixed_market_bid_cost", 18487.236, 30.0, 31.0),
    ]
    for (name, sys_name, _, my_no_load, my_initial_input) in test_cases
        @testset "$name" begin
            sys = build_system(PSITestSystems, "c_$(sys_name)")
            unit1 = get_component(ThermalStandard, sys, "Test Unit1")
            replace_with_renewable!(sys, unit1)
            rg1 = get_component(PSY.RenewableDispatch, sys, "RG1")
            test_market_bid_cost_models(
                sys,
                rg1,
                my_no_load,
                my_initial_input,
            )
        end
    end
end

function zero_out_non_incremental_curve!(sys::PSY.System, unit::PSY.Component)
    cost = deepcopy(get_operation_cost(unit)::MarketBidCost)
    set_no_load_cost!(cost, 0.0)
    set_start_up!(cost, (hot = 0.0, warm = 0.0, cold = 0.0))
    set_shut_down!(cost, 0.0)
    if get_incremental_offer_curves(cost) isa IS.TimeSeriesKey
        zero_ts = _make_deterministic_ts(sys, "initial_input", 0.0, 0.0, 0.0)
        zero_ts_key = add_time_series!(sys, unit, zero_ts)
        set_incremental_initial_input!(cost, zero_ts_key)
    else
        # set x coordinate and y coordinate of minimum power to 0.0
        base_curve = get_value_curve(get_incremental_offer_curves(cost))
        x_coords = deepcopy(get_x_coords(base_curve))
        slopes = deepcopy(get_slopes(base_curve))
        if x_coords[1] > 0.0
            x_coords[1] = 0.0
            new_curve = PiecewiseIncrementalCurve(0.0, x_coords, slopes)
            set_incremental_offer_curves!(cost, CostCurve(new_curve))
        end
    end
    set_operation_cost!(unit, cost)
end

@testset "Compare Renewable and Standard Thermal MarketBidCost" begin
    (name, sys_name) = ("Base case", "fixed_market_bid_cost")
    sys = build_system(PSITestSystems, "c_$(sys_name)")
    unit1 = get_component(ThermalStandard, sys, "Test Unit1")
    replace_with_renewable!(sys, unit1; use_thermal_max_power = true)
    rg1 = get_component(PSY.RenewableDispatch, sys, "RG1")
    zero_out_non_incremental_curve!(sys, rg1)
    set_name!(sys, "sys_renewable")
    results_renewable = test_market_bid_cost_models(
        sys,
        rg1,
        0.0,
        0.0;
        skip_setting = true,
        save_obj_fcn = true,
    )

    sys_thermal = build_system(PSITestSystems, "c_$(sys_name)")
    unit1 = get_component(ThermalStandard, sys_thermal, "Test Unit1")
    set_active_power_limits!(
        unit1,
        (min = 0.0, max = get_active_power_limits(unit1).max),
    )
    set_operation_cost!(unit1, deepcopy(get_operation_cost(rg1)))
    set_name!(sys_thermal, "sys_thermal")

    results_thermal = test_market_bid_cost_models(
        sys_thermal,
        unit1,
        0.0,
        0.0;
        skip_setting = true,
        save_obj_fcn = true,
    )

    # check that the operation costs are the same.
    IS.compare_values(get_operation_cost(rg1), get_operation_cost(unit1))
    for thermal_unit in get_components(ThermalStandard, sys)
        sys_thermal_unit =
            get_component(ThermalStandard, sys_thermal, get_name(thermal_unit))
        IS.compare_values(
            thermal_unit,
            sys_thermal_unit,
        )
    end
    for load in get_components(PSY.PowerLoad, sys)
        IS.compare_values(load, get_component(PSY.PowerLoad, sys_thermal, get_name(load)))
    end

    @test PSI.read_optimizer_stats(results_thermal)[!, "objective_value"] ==
          PSI.read_optimizer_stats(results_renewable)[!, "objective_value"]
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

function load_and_fix_system(args...; kwargs...)
    sys = Logging.with_logger(Logging.NullLogger()) do
        build_system(args...; kwargs...)
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
    interval;
    override_min_x = nothing,
    create_extra_tranches = false,
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

    if !isnothing(override_min_x)
        for sub_x in xs1
            sub_x[1] = override_min_x
        end
        for sub_x in xs2
            sub_x[1] = override_min_x
        end
    end

    if create_extra_tranches
        # Split the first tranche of the first timestep (xs1, ys1) into two; split the last tranche of the last timestep of (xs2, ys2) into three
        xs1[1] = [xs1[1][1], (xs1[1][1] + xs1[1][2]) / 2, xs1[1][2:end]...]
        ys1[1] = [ys1[1][1], ys1[1][1], ys1[1][2:end]...]

        xs2[end] = [
            xs2[end][1:(end - 1)]...,
            (2 * xs2[end][end - 1] + xs2[end][end]) / 3,
            (xs2[end][end - 1] + 2 * xs2[end][end]) / 3,
            xs2[end][end],
        ]
        ys2[end] = [ys2[end][1:(end - 1)]..., ys2[end][end], ys2[end][end], ys2[end][end]]
    end

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
    base_startup = Tuple(get_start_up(get_operation_cost(unit1)))
    base_shutdown = get_shut_down(get_operation_cost(unit1))
    @assert get_operation_cost(unit1) isa MarketBidCost
    startup_ts_1 = _make_deterministic_ts(
        "start_up",
        base_startup,
        res_incr,
        interval_incr,
        24,
        Day(1),
    )
    set_start_up!(sys, unit1, startup_ts_1)
    shutdown_ts_1 =
        _make_deterministic_ts(
            "shut_down",
            base_shutdown,
            res_incr,
            interval_incr,
            24,
            Day(1),
        )
    set_shut_down!(sys, unit1, shutdown_ts_1)
    return startup_ts_1, shutdown_ts_1
end

# Layer of indirection to upgrade problem results to look like simulation results
_maybe_upgrade_to_dict(input::AbstractDict) = input
_maybe_upgrade_to_dict(input::DataFrame) =
    SortedDict{DateTime, DataFrame}(first(input[!, :DateTime]) => input)

read_variable_dict(
    res::IS.Results,
    var_name::Type{<:PSI.VariableType},
    comp_type::Type{<:PSY.Component},
) =
    _maybe_upgrade_to_dict(read_variable(res, var_name, comp_type))
read_parameter_dict(
    res::IS.Results,
    par_name::Type{<:PSI.ParameterType},
    comp_type::Type{<:PSY.Component},
) =
    _maybe_upgrade_to_dict(read_parameter(res, par_name, comp_type))

function load_sys_incr()
    # NOTE we are using the fixed one so we can add time series ourselves
    sys = load_and_fix_system(
        PSITestSystems,
        "c_fixed_market_bid_cost",
    )
    tweak_system!(sys, 1.05, 1.0, 1.0)
    get_y_coords(
        get_function_data(
            get_value_curve(
                get_incremental_offer_curves(
                    get_operation_cost(get_component(ThermalStandard, sys, "Test Unit2")),
                ),
            ),
        ),
    )[1] *= 0.9
    return sys
end

# currently unused. LK: I find it easier to just take sys_incr and replace PowerLoads
# with InterruptiblePowerLoads.
function load_sys_decr()
    sys = load_and_fix_system(PSITestSystems, "c_sys5_il")
    return sys
end

function replace_load_with_interruptible!(sys::System)
    @assert !isempty(get_components(PSY.PowerLoad, sys))
    load1 = first(get_components(PSY.PowerLoad, sys))
    interruptible_load = PSY.InterruptiblePowerLoad(;
        name = get_name(load1) * "_interruptible",
        bus = get_bus(load1),
        available = get_available(load1),
        active_power = get_active_power(load1),
        reactive_power = get_reactive_power(load1),
        max_active_power = get_max_active_power(load1),
        max_reactive_power = get_max_reactive_power(load1),
        operation_cost = PSY.LoadCost(nothing),
        base_power = get_base_power(load1),
        conformity = get_conformity(load1),
    )
    add_component!(sys, interruptible_load)
    for ts_key in get_time_series_keys(load1)
        ts = get_time_series(load1, ts_key)
        add_time_series!(
            sys,
            interruptible_load,
            ts,
        )
    end
    remove_component!(sys, load1)
end

# still erroring. try adding a 2nd load to see if that helps?
const ZERO_OUT_THERMAL_COST = true
function load_sys_decr2()
    sys = load_and_fix_system(
        PSITestSystems,
        "c_fixed_market_bid_cost",
    )
    replace_load_with_interruptible!(sys)
    interruptible_load = first(get_components(PSY.InterruptiblePowerLoad, sys))
    selector = make_selector(PSY.InterruptiblePowerLoad, get_name(interruptible_load))
    add_mbc!(sys, selector; incremental = false, decremental = true)
    # replace the MBCs on the thermals with ThermalCost objects.
    for comp in get_components(ThermalStandard, sys)
        old_cost = get_operation_cost(comp)
        old_cost isa MarketBidCost || continue
        new_op_cost = ThermalGenerationCost(;
            variable = get_incremental_offer_curves(old_cost),
            start_up = get_start_up(old_cost),
            shut_down = get_shut_down(old_cost),
            fixed = 0.0,
        )
        set_operation_cost!(comp, new_op_cost)
    end
    if ZERO_OUT_THERMAL_COST
        for comp in get_components(ThermalGen, sys)
            set_operation_cost!(
                comp,
                ThermalGenerationCost(;
                    variable = CostCurve(
                        LinearCurve(0.0),
                    ),
                    start_up = (hot = 0.0, warm = 0.0, cold = 0.0),
                    shut_down = 0.0,
                    fixed = 0.0,
                ),
            )
        end
    end
    return sys
end

"""
Create a system with initial input and variable cost time series. Lots of options:

# Arguments:
  - `initial_varies`: whether the initial input time series should have values that vary
    over time (as opposed to a time series with constant values over time)
  - `breakpoints_vary`: whether the breakpoints in the variable cost time series should vary
    over time
  - `slopes_vary`: whether the slopes of the variable cost time series should vary over time
  - `modify_baseline_pwl`: optional, a function to modify the baseline piecewise linear cost
    `FunctionData` from which the variable cost time series is calculated
  - `do_override_min_x`: whether to override the P1 to be equal to the minimum power in all
    time steps
  - `create_extra_tranches`: whether to create extra tranches in some time steps by
    splitting one tranche into two
  - `active_components`: a `ComponentSelector` specifying which components should get time
    series
  - `initial_input_names_vary`: whether the initial input time series names should vary over
    components
  - `variable_cost_names_vary`: whether the variable cost time series names should vary over
    components
"""
function build_sys_incr(
    initial_varies::Bool,
    breakpoints_vary::Bool,
    slopes_vary::Bool;
    modify_baseline_pwl = nothing,
    do_override_min_x = true,
    create_extra_tranches = false,
    active_components = SEL_INCR,
    initial_input_names_vary = false,
    variable_cost_names_vary = false,
)
    sys = load_sys_incr()
    @assert !isempty(get_components(active_components, sys)) "No components selected"
    extend_mbc!(
        sys,
        active_components;
        initial_varies = initial_varies,
        breakpoints_vary = breakpoints_vary,
        slopes_vary = slopes_vary,
        modify_baseline_pwl = modify_baseline_pwl,
        do_override_min_x = do_override_min_x,
        create_extra_tranches = create_extra_tranches,
        initial_input_names_vary = initial_input_names_vary,
        variable_cost_names_vary = variable_cost_names_vary,
    )
    return sys
end

function build_sys_decr2(
    initial_varies::Bool,
    breakpoints_vary::Bool,
    slopes_vary::Bool;
    modify_baseline_pwl = nothing,
    do_override_min_x = true,
    create_extra_tranches = false,
    active_components = SEL_DECR,
    initial_input_names_vary = false,
    variable_cost_names_vary = false,
)
    sys = load_sys_decr2()
    @assert !isempty(get_components(active_components, sys)) "No components selected"
    extend_mbc!(
        sys,
        active_components;
        initial_varies = initial_varies,
        breakpoints_vary = breakpoints_vary,
        slopes_vary = slopes_vary,
        modify_baseline_pwl = modify_baseline_pwl,
        do_override_min_x = do_override_min_x,
        create_extra_tranches = create_extra_tranches,
        initial_input_names_vary = initial_input_names_vary,
        variable_cost_names_vary = variable_cost_names_vary,
    )

    # make the max_active_power time series constant.
    il = first(get_components(PSY.InterruptiblePowerLoad, sys))
    for ts_key in get_time_series_keys(il)
        if get_name(ts_key) == "max_active_power"
            max_active_power_ts = get_time_series(
                first(get_components(PSY.InterruptiblePowerLoad, sys)),
                ts_key,
            )
            max_max_active_power = maximum(maximum(values(max_active_power_ts.data)))
            remove_time_series!(sys, Deterministic, il, "max_active_power")
            new_ts = _make_deterministic_ts(
                sys,
                "max_active_power",
                max_max_active_power,
                0.0,
                0.0,
            )
            add_time_series!(sys, il, new_ts)
            break
        end
    end
    return sys
end

tweak_for_decremental_initial!(sys::PSY.System) =
    tweak_system!(sys, 1.0, 1.2, 0.5)

function _read_one_value(res, var_name, gentype, unit_name)
    df = @chain begin
        vcat(values(read_variable_dict(res, var_name, gentype))...)
        @rsubset(:name == unit_name)
        @combine(:value = sum(:value))
    end
    return df[1, 1]
end

function build_generic_mbc_model(sys::System;
    multistart::Bool = false,
    standard::Bool = false,
    device_to_formulation = Dict{
        Type{<:PSY.Device},
        Type{<:PSI.AbstractDeviceFormulation},
    }(),
)
    template = ProblemTemplate(
        NetworkModel(
            CopperPlatePowerModel;
            duals = [CopperPlateBalanceConstraint],
        ),
    )

    set_formulations!(
        template,
        sys,
        device_to_formulation,
    )
    if standard
        set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
    end
    if multistart
        set_device_model!(template, ThermalMultiStart, ThermalMultiStartUnitCommitment)
    end

    model = DecisionModel(
        template,
        sys;
        name = "UC",
        store_variable_names = true,
        optimizer = HiGHS_optimizer_small_gap,
        system_to_file = false,
    )
    return model
end

function run_generic_mbc_prob(
    sys::System;
    multistart::Bool = false,
    standard = false,
    test_success = true,
    save_obj_fcn::Bool = false,
    is_decremental::Bool = false,
    device_to_formulation = Dict{
        Type{<:PSY.Device},
        Type{<:PSI.AbstractDeviceFormulation},
    }(),
)
    model = build_generic_mbc_model(
        sys;
        multistart = multistart,
        standard = standard,
        device_to_formulation = device_to_formulation,
    )
    build_result = build!(model; output_dir = test_path)
    test_success && @test build_result == PSI.ModelBuildStatus.BUILT
    solve_result = solve!(model)
    test_success && @test solve_result == PSI.RunStatus.SUCCESSFULLY_FINALIZED
    res = OptimizationProblemResults(model)
    if save_obj_fcn
        adj = is_decremental ? "decr" : "incr"
        save_objective_function(
            model,
            joinpath(DOWNLOADS, "$(get_name(sys))_$(adj)_prob_objective_function.txt"),
        )
        save_constraints(
            model,
            joinpath(DOWNLOADS, "$(get_name(sys))_$(adj)_prob_constraints.txt"),
        )
    end
    return model, res
end

function run_generic_mbc_sim(
    sys::System;
    multistart::Bool = false,
    in_memory_store::Bool = false,
    standard::Bool = false,
    test_success = true,
    save_obj_fcn::Bool = false,
    is_decremental::Bool = false,
    device_to_formulation = Dict{
        Type{<:PSY.Device},
        Type{<:PSI.AbstractDeviceFormulation},
    }(),
)
    model = build_generic_mbc_model(
        sys;
        multistart = multistart,
        standard = standard,
        device_to_formulation = device_to_formulation,
    )
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

    test_success && @test build!(sim; serialize = false) == PSI.SimulationBuildStatus.BUILT
    test_success &&
        @test execute!(sim; enable_progress_bar = true, in_memory = in_memory_store) ==
              PSI.RunStatus.SUCCESSFULLY_FINALIZED

    sim_res = SimulationResults(sim)
    res = get_decision_problem_results(sim_res, "UC")
    if save_obj_fcn
        adj = is_decremental ? "decr" : "incr"
        save_objective_function(
            model,
            joinpath(DOWNLOADS, "$(get_name(sys))_$(adj)_sim_objective_function.txt"),
        )
        save_constraints(
            model,
            joinpath(DOWNLOADS, "$(get_name(sys))_$(adj)_sim_constraints.txt"),
        )
    end
    return model, res
end

"""
Run a simple simulation with the system and return information useful for testing
time-varying startup and shutdown functionality. Pass `simulation = false` to use a single
decision model, `true` for a full simulation.
"""
function run_startup_shutdown_test(
    sys::System;
    multistart::Bool = false,
    simulation = true,
    in_memory_store::Bool = false,
)
    model, res = if simulation
        run_generic_mbc_sim(sys; multistart = multistart, in_memory_store = in_memory_store)
    else
        run_generic_mbc_prob(sys; multistart = multistart)
    end

    # Test correctness of written shutdown cost parameters
    # TODO test startup too once we are able to write those
    gentype = multistart ? ThermalMultiStart : ThermalStandard
    genname = multistart ? "115_STEAM_1" : "Test Unit1"
    sh_param = read_parameter_dict(res, PSI.ShutdownCostParameter, gentype)
    for (step_dt, step_df) in pairs(sh_param)
        for gen_name in unique(step_df.name)
            comp = get_component(gentype, sys, gen_name)
            fc_comp =
                get_shut_down(comp, PSY.get_operation_cost(comp); start_time = step_dt)
            @test all(step_df[!, :DateTime] .== TimeSeries.timestamp(fc_comp))
            @test all(
                isapprox.(
                    @rsubset(step_df, :name == gen_name).value,
                    TimeSeries.values(fc_comp),
                ),
            )
        end
    end

    # These decisions need to be equal between certain pairs of problems/simulations and also need to be approx_geq_1
    decisions = if multistart
        (
            _read_one_value(res, PSI.HotStartVariable, gentype, genname),
            _read_one_value(res, PSI.WarmStartVariable, gentype, genname),
            _read_one_value(res, PSI.ColdStartVariable, gentype, genname),
            _read_one_value(res, PSI.StopVariable, gentype, genname),
            _read_one_value(res, PSI.OnVariable, gentype, genname),
        )
    else
        (
            _read_one_value(res, PSI.StartVariable, gentype, genname),
            _read_one_value(res, PSI.StopVariable, gentype, genname),
            _read_one_value(res, PSI.OnVariable, gentype, genname),
        )
    end

    # These decisions need to be equal between certain pairs of problems/simulations but need not be approx_geq_1 for the test to be valid
    nullable_decisions = if multistart
        (
            _read_one_value(res, PSI.PowerAboveMinimumVariable, gentype, genname),
            # sometimes useful for debugging clarity to check *another* generator's decisions
            _read_one_value(res, PSI.OnVariable, gentype, "101_CT_1"),
        )
    else
        ()
    end
    return model, res, decisions, nullable_decisions
end

has_initial_input(
    is_decremental::Bool,
    device_to_formulation::Dict{
        <:Type{<:PSY.Device},
        <:Type{<:PSI.AbstractDeviceFormulation},
    },
) =
    !is_decremental ||
    get(device_to_formulation, InterruptiblePowerLoad, nothing) != PowerLoadDispatch

"""
Run a simple simulation with the system and return information useful for testing
time-varying startup and shutdown functionality.  Pass `simulation = false` to use a single
decision model, `true` for a full simulation.
"""
function run_mbc_sim(
    sys::System;
    is_decremental::Bool = false,
    simulation = true,
    in_memory_store = false,
    standard = false,
    save_obj_fcn = false,
    device_to_formulation = Dict{
        Type{<:PSY.Device},
        Type{<:PSI.AbstractDeviceFormulation},
    }(),
    # save_constraints = false,
)
    model, res = if simulation
        run_generic_mbc_sim(
            sys;
            in_memory_store = in_memory_store,
            standard = standard,
            save_obj_fcn = save_obj_fcn,
            is_decremental = is_decremental,
            device_to_formulation = device_to_formulation,
        )
    else
        run_generic_mbc_prob(
            sys;
            standard = standard,
            save_obj_fcn = save_obj_fcn,
            is_decremental = is_decremental,
            device_to_formulation = device_to_formulation,
        )
    end

    # TODO test slopes, breakpoints too once we are able to write those
    if is_decremental
        comp_type = InterruptiblePowerLoad
        # TODO the PowerLoadDispatch device formulation doesn't have this parameter, 
        # because there is no off/on choice.
        param_type = PSI.DecrementalCostAtMinParameter
        initial_getter = get_decremental_initial_input
    else
        comp_type = ThermalStandard
        param_type = PSI.IncrementalCostAtMinParameter
        initial_getter = get_incremental_initial_input
    end
    # the PowerLoadDispatch device formulation doesn't have 
    # DecrementalCostAtMinParameter nor OnVariable. 

    if has_initial_input(is_decremental, device_to_formulation)
        init_param = read_parameter_dict(res, param_type, comp_type)
        for (step_dt, step_df) in pairs(init_param)
            for gen_name in unique(step_df.name)
                comp = get_component(comp_type, sys, gen_name)
                ii_comp = initial_getter(
                    comp,
                    PSY.get_operation_cost(comp);
                    start_time = step_dt,
                )
                @test all(step_df[!, :DateTime] .== TimeSeries.timestamp(ii_comp))
                @test all(
                    isapprox.(
                        @rsubset(step_df, :name == gen_name).value,
                        TimeSeries.values(ii_comp),
                    ),
                )
            end
        end
    end
    # NOTE this could be rewritten nicely using PowerAnalytics
    comp = get_component(is_decremental ? SEL_DECR : SEL_INCR, sys)
    @assert !isnothing(comp)
    gentype, genname = typeof(comp), get_name(comp) # FIXME erroring at get_name.
    if has_initial_input(is_decremental, device_to_formulation)
        decisions = (
            _read_one_value(res, PSI.OnVariable, gentype, genname),
            _read_one_value(res, PSI.ActivePowerVariable, gentype, genname),
        )
    else
        decisions = (
            1.0, # placeholder so return type is consistent.
            _read_one_value(res, PSI.ActivePowerVariable, gentype, genname),
        )
    end
    return model, res, decisions, ()
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
    combined_vars = Dict{DateTime, DataFrame}()
    for timestamp in keys(hot_vars)
        hot = hot_vars[timestamp]
        warm = warm_vars[timestamp]
        cold = cold_vars[timestamp]
        combined_vars[timestamp] = @chain DataFrames.rename(hot, :value => :hot) begin
            innerjoin(DataFrames.rename(warm, :value => :warm); on = [:DateTime, :name])
            innerjoin(
                DataFrames.rename(cold, :value => :cold);
                on = [:DateTime, :name],
            )
            @transform(@byrow(:value = (:hot, :warm, :cold)))
            @select(:DateTime, :name, :value)
        end
    end
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
    IS.@assert_op Set(collect(keys(start_vars))) == Set(collect(keys(stop_vars)))
    for step_dt in keys(start_vars)
        start_df = start_vars[step_dt]
        stop_df = stop_vars[step_dt]
        @assert unique(start_df.name) == unique(stop_df.name)
        @assert start_df[!, :DateTime] == stop_df[!, :DateTime]
        timestamps = unique(start_df.DateTime)
        component_names = unique(start_df.name)
        dfs = Vector{DataFrame}()
        for gen_name in component_names
            comp = get_component(gentype, sys, gen_name)
            cost = PSY.get_operation_cost(comp)
            (cost isa PSY.MarketBidCost) || continue
            PSI.is_time_variant(get_start_up(cost)) || continue
            @assert PSI.is_time_variant(get_shut_down(cost))
            startup_ts = get_start_up(comp, cost; start_time = step_dt)
            shutdown_ts = get_shut_down(comp, cost; start_time = step_dt)

            @assert all(unique(start_df.DateTime) .== TimeSeries.timestamp(startup_ts))
            @assert all(unique(start_df.DateTime) .== TimeSeries.timestamp(shutdown_ts))
            startup_values = if multistart
                TimeSeries.values(startup_ts)
            else
                getproperty.(TimeSeries.values(startup_ts), :hot)
            end
            push!(
                dfs,
                DataFrame(
                    :DateTime => timestamps,
                    :name => repeat([gen_name], length(timestamps)),
                    :value =>
                        LinearAlgebra.dot.(
                            @rsubset(start_df, :name == gen_name).value,
                            startup_values,
                        ) .+
                        @rsubset(stop_df, :name == gen_name).value .*
                        TimeSeries.values(shutdown_ts),
                ),
            )
        end
        if !isempty(dfs)
            result[step_dt] = vcat(dfs...)
        end
    end
    return result
end

function cost_due_to_time_varying_mbc(
    sys::System,
    res::IS.Results;
    is_decremental = false,
    device_to_formulation = Dict{
        Type{<:PSY.Device},
        Type{<:PSI.AbstractDeviceFormulation},
    }(),
)
    gentype = is_decremental ? InterruptiblePowerLoad : ThermalStandard
    power_vars = read_variable_dict(res, PSI.ActivePowerVariable, gentype)
    result = SortedDict{DateTime, DataFrame}()
    if has_initial_input(is_decremental, device_to_formulation)
        on_vars = read_variable_dict(res, PSI.OnVariable, gentype)
        @assert all(keys(on_vars) .== keys(power_vars))
        @assert !isempty(keys(on_vars))
    end
    for step_dt in keys(power_vars)
        power_df = power_vars[step_dt]
        step_df = DataFrame(:DateTime => unique(power_df.DateTime))
        gen_names = unique(power_df.name)
        @assert !isempty(gen_names)
        @assert any([
            get_operation_cost(comp) isa MarketBidCost for
            comp in get_components(gentype, sys)
        ])
        if has_initial_input(is_decremental, device_to_formulation)
            on_df = on_vars[step_dt]
            @assert names(on_df) == names(power_df)
            @assert on_df[!, :DateTime] == power_df[!, :DateTime]
        end
        for gen_name in gen_names
            comp = get_component(gentype, sys, gen_name)
            cost = PSY.get_operation_cost(comp)
            (cost isa MarketBidCost) || continue
            step_df[!, gen_name] .= 0.0
            if has_initial_input(is_decremental, device_to_formulation)
                ii_getter = if is_decremental
                    get_decremental_initial_input
                else
                    get_incremental_initial_input
                end
                if PSI.is_time_variant(ii_getter(cost))
                    # initial cost: initial input time series multiplied by OnVariable value.
                    ii_ts = ii_getter(comp, cost; start_time = step_dt)
                    @assert all(unique(on_df.DateTime) .== TimeSeries.timestamp(ii_ts))
                    step_df[!, gen_name] .+=
                        @rsubset(on_df, :name == gen_name).value .*
                        TimeSeries.values(ii_ts)
                end
            end
            oc_getter =
                is_decremental ?
                get_decremental_offer_curves :
                get_incremental_offer_curves
            if PSI.is_time_variant(oc_getter(cost))
                vc_ts = oc_getter(comp, cost; start_time = step_dt)
                @assert all(unique(power_df.DateTime) .== TimeSeries.timestamp(vc_ts))
                # variable cost: cost function time series evaluated at ActivePowerVariable value.
                step_df[!, gen_name] .+=
                    _calc_pwi_cost.(
                        @rsubset(power_df, :name == gen_name).value,
                        TimeSeries.values(vc_ts),
                    ) # could replace with direct evaluation, now that it is implemented in IS.
            end
        end
        measure_vars = [x for x in names(step_df) if x != "DateTime"]
        # rows represent: [time, component, time-varying MBC cost for {component} at {time}]
        result[step_dt] =
            DataFrames.stack(
                step_df,
                measure_vars;
                variable_name = :name,
                value_name = :value,
            )
    end
    return result
end

"""
Helper function to tweak load powers, non-MBC generator powers, and non-MBC generator costs
to exercise the generators we want to test.

Multiplies {} for {} by {}:
- max active power, all loads, load_pow_mult
- active power limits, non-MBC ThermalStandard, therm_pow_mult
- operational costs, non-MBC ThermalStandard, therm_price_mult
"""
function tweak_system!(sys::System, load_pow_mult, therm_pow_mult, therm_price_mult)
    for load in get_components(PowerLoad, sys)
        set_max_active_power!(load, get_max_active_power(load) * load_pow_mult)
    end
    # replace with type of component?
    for therm in get_components(ThermalStandard, sys)
        op_cost = get_operation_cost(therm)
        op_cost isa MarketBidCost && continue
        with_units_base(sys, UnitSystem.DEVICE_BASE) do
            old_limits = get_active_power_limits(therm)
            new_limits = (min = old_limits.min, max = old_limits.max * therm_pow_mult)
            set_active_power_limits!(therm, new_limits)
        end
        if get_variable(op_cost) isa CostCurve{LinearCurve} ||
           get_variable(op_cost) isa CostCurve{QuadraticCurve}
            prop = get_proportional_term(get_value_curve(get_variable(op_cost)))
            set_variable!(op_cost, CostCurve(LinearCurve(prop * therm_price_mult)))
        elseif get_variable(op_cost) isa CostCurve{PiecewiseIncrementalCurve}
            pwl = get_value_curve(get_variable(op_cost))
            new_pwl = PiecewiseIncrementalCurve(
                therm_price_mult * get_initial_input(pwl),
                get_x_coords(pwl),
                therm_price_mult * get_slopes(pwl),
            )
            set_variable!(op_cost, CostCurve(new_pwl))
        else
            error("Unhandled operation cost variable type $(typeof(get_variable(op_cost)))")
        end
    end
end

function create_multistart_sys(with_increments::Bool, load_mult, therm_mult; add_ts = true)
    @assert add_ts || !with_increments
    c_sys5_pglib = load_and_fix_system(PSITestSystems, "c_sys5_pglib")
    tweak_system!(c_sys5_pglib, load_mult, 1.0, therm_mult)
    ms_comp = get_component(SEL_MULTISTART, c_sys5_pglib)
    old_op = get_operation_cost(ms_comp)
    old_ic = IncrementalCurve(get_value_curve(get_variable(old_op)))
    new_ii = get_initial_input(old_ic) + get_fixed(old_op)
    new_ic = IncrementalCurve(get_function_data(old_ic), new_ii, nothing)
    set_operation_cost!(
        ms_comp,
        MarketBidCost(;
            no_load_cost = nothing,
            start_up = (hot = 300.0, warm = 450.0, cold = 500.0),
            shut_down = 100.0,
            incremental_offer_curves = CostCurve(new_ic),
        ),
    )

    add_ts && add_startup_shutdown_ts_b!(c_sys5_pglib, with_increments)
    return c_sys5_pglib
end

# See run_startup_shutdown_obj_fun_test for explanation
function _obj_fun_test_helper(
    ground_truth_1,
    ground_truth_2,
    res1,
    res2;
    is_decremental = false,
)
    @assert all(keys(ground_truth_1) .== keys(ground_truth_2))
    # total cost due to time-varying MBCs in each scenario
    total1 =
        [only(@combine(df, :total = sum(:value)).total) for df in values(ground_truth_1)]
    total2 =
        [only(@combine(df, :total = sum(:value)).total) for df in values(ground_truth_2)]
    if !is_decremental
        ground_truth_diff = total2 .- total1  # How much did the cost increase between simulation 1 and simulation 2 for each step
    else
        # objective = cost - benefit. higher load prices => more willing to pay, more benefit.
        # so we get an extra negative sign, since we're increasing benefit, not cost.
        ground_truth_diff = total1 .- total2
    end

    obj1 = PSI.read_optimizer_stats(res1)[!, "objective_value"]
    obj2 = PSI.read_optimizer_stats(res2)[!, "objective_value"]
    obj_diff = obj2 .- obj1

    # An assumption in this line of testing is that our perturbations are small enough that
    # they don't actually change the decisions, just slightly alter the cost. If this assert
    # triggers, that assumption is likely violated.
    @assert isapprox(obj1, obj2; atol = 10, rtol = 0.01) "obj1 ($obj1) and obj2 ($obj2) are supposed to differ, but they differ by an improbably large amount ($obj_diff) -- the perturbations are likely affecting the decisions"

    # Make sure there is some real difference between the two scenarios
    @assert !any(isapprox.(ground_truth_diff, 0.0; atol = 0.0001))
    # Make sure the difference is reflected correctly in the objective value
    if !all(isapprox.(obj_diff, ground_truth_diff; atol = 0.0001))
        @show obj_diff
        @show ground_truth_diff
        @show obj_diff .- ground_truth_diff
    end
    @test all(isapprox.(obj_diff, ground_truth_diff; atol = 0.0001))
    return all(isapprox.(obj_diff, ground_truth_diff; atol = 0.0001))
end

"""
The methodology here is: run a model or simulation where the startup and shutdown time
series have constant values through time, then run a nearly identical model/simulation where
the values vary very slightly through time, not enough to affect the decisions but enough to
affect the objective value, then compare the size of the objective value change to an
expectation computed manually.

Pass `simulation = false` to use a single decision model, `true` for a full simulation.
Pass `in_memory_store = true` to use an in-memory store for the simulation. Default is HDF5.
"""
function run_startup_shutdown_obj_fun_test(
    sys1,
    sys2;
    multistart::Bool = false,
    simulation = true,
    in_memory_store::Bool = false,
)
    _, res1, decisions1, nullable_decisions1 =
        run_startup_shutdown_test(
            sys1;
            multistart = multistart,
            simulation = simulation,
            in_memory_store = in_memory_store,
        )
    _, res2, decisions2, nullable_decisions2 =
        run_startup_shutdown_test(
            sys2;
            multistart = multistart,
            simulation = simulation,
            in_memory_store = in_memory_store,
        )

    all_decisions1 = (decisions1..., nullable_decisions1...)
    all_decisions2 = (decisions2..., nullable_decisions2...)

    if !all(isapprox.(all_decisions1, all_decisions2))
        @show all_decisions1
        @show all_decisions2
    end
    @assert all(isapprox.(all_decisions1, all_decisions2))

    ground_truth_1 =
        cost_due_to_time_varying_startup_shutdown(sys1, res1; multistart = multistart)
    ground_truth_2 =
        cost_due_to_time_varying_startup_shutdown(sys2, res2; multistart = multistart)

    _obj_fun_test_helper(ground_truth_1, ground_truth_2, res1, res2)
    return decisions1, decisions2
end

# See run_startup_shutdown_obj_fun_test for explanation
function run_mbc_obj_fun_test(
    sys1,
    sys2;
    is_decremental::Bool = false,
    simulation = true,
    in_memory_store = false,
    save_obj_fcn = false,
    device_to_formulation = Dict{
        Type{<:PSY.Device},
        Type{<:PSI.AbstractDeviceFormulation},
    }(),
)
    _, res1, decisions1, nullable_decisions1 =
        run_mbc_sim(
            sys1;
            is_decremental = is_decremental,
            simulation = simulation,
            in_memory_store = in_memory_store,
            save_obj_fcn = save_obj_fcn,
            device_to_formulation = device_to_formulation,
        )
    _, res2, decisions2, nullable_decisions2 =
        run_mbc_sim(
            sys2;
            is_decremental = is_decremental,
            simulation = simulation,
            in_memory_store = in_memory_store,
            save_obj_fcn = save_obj_fcn,
            device_to_formulation = device_to_formulation,
        )

    all_decisions1 = (decisions1..., nullable_decisions1...)
    all_decisions2 = (decisions2..., nullable_decisions2...)

    if !all(isapprox.(all_decisions1, all_decisions2))
        @show all_decisions1
        @show all_decisions2
    end
    @assert all(isapprox.(all_decisions1, all_decisions2))

    ground_truth_1 =
        cost_due_to_time_varying_mbc(sys1, res1; is_decremental = is_decremental,
            device_to_formulation = device_to_formulation)
    ground_truth_2 =
        cost_due_to_time_varying_mbc(sys2, res2; is_decremental = is_decremental,
            device_to_formulation = device_to_formulation)

    success = _obj_fun_test_helper(
        ground_truth_1,
        ground_truth_2,
        res1,
        res2;
        is_decremental = is_decremental,
    )
    if !success
        @show simulation
        @show in_memory_store
    end
    return decisions1, decisions2
end

function tweak_for_startup_shutdown!(sys::System)
    tweak_system!(sys::System, 0.8, 1.0, 1.0)
end

function _calc_pwi_cost(active_power::Float64, pwi::PiecewiseStepData)
    isapprox(active_power, 0.0) && return 0.0
    breakpoints = get_x_coords(pwi)
    slopes = get_y_coords(pwi)
    @assert active_power >= first(breakpoints) && active_power <= last(breakpoints)
    i_leq = findlast(<=(active_power), breakpoints)
    cost =
        sum(slopes[1:(i_leq - 1)] .* (breakpoints[2:i_leq] .- breakpoints[1:(i_leq - 1)]))
    (active_power > breakpoints[i_leq]) &&
        (cost += slopes[i_leq] * (active_power - breakpoints[i_leq]))
    return cost
end

"Test that the two systems (typically one without time series and one with constant time series) simulate the same"
function test_generic_mbc_equivalence(sys0, sys1; kwargs...)
    for runner in (run_generic_mbc_prob, run_generic_mbc_sim)  # test with both a single problem and a full simulation
        _, res0 = runner(sys0; kwargs...)
        _, res1 = runner(sys1; kwargs...)
        obj_val_0 = PSI.read_optimizer_stats(res0)[!, "objective_value"]
        obj_val_1 = PSI.read_optimizer_stats(res1)[!, "objective_value"]
        @test isapprox(obj_val_0, obj_val_1; atol = 0.0001)
    end
end

approx_geq_1(x; kwargs...) = (x >= 1.0) || isapprox(x, 1.0; kwargs...)

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
    test_generic_mbc_equivalence(sys0, sys1; multistart = false)

    # Test that perturbing the time series perturbs the objective value as expected
    sys2 = load_and_fix_system(PSITestSystems, "c_fixed_market_bid_cost")
    tweak_for_startup_shutdown!(sys2)
    add_startup_shutdown_ts_a!(sys2, true)

    for use_simulation in (false, true)
        in_memory_store_opts = use_simulation ? [false, true] : [false]
        for in_memory_store in in_memory_store_opts
            (decisions1, decisions2) =
                run_startup_shutdown_obj_fun_test(
                    sys1,
                    sys2;
                    simulation = use_simulation,
                    in_memory_store = in_memory_store,
                )
            # Make sure our tests included sufficent startups and shutdowns
            @assert all(approx_geq_1.(decisions1))
        end
    end
end

@testset "MarketBidCost with time series startup and shutdown, ThermalMultiStart" begin
    # The arguments to create_multistart_sys were tuned empirically to ensure (a) the
    # behavior under test is exercised and (b) the small perturbations to the costs aren't
    # enough to change the decisions that form the correct solution

    # Scenario 1: hot and warm starts
    c_sys5_pglib0a = create_multistart_sys(false, 1.0, 7.45; add_ts = false)
    c_sys5_pglib1a = create_multistart_sys(false, 1.0, 7.45)
    c_sys5_pglib2a = create_multistart_sys(true, 1.0, 7.45)

    # Scenario 2: hot and cold starts
    c_sys5_pglib0b = create_multistart_sys(false, 1.05, 7.4; add_ts = false)
    c_sys5_pglib1b = create_multistart_sys(false, 1.05, 7.4)
    c_sys5_pglib2b = create_multistart_sys(true, 1.05, 7.4)

    test_generic_mbc_equivalence(c_sys5_pglib0a, c_sys5_pglib1a; multistart = true)
    test_generic_mbc_equivalence(c_sys5_pglib0b, c_sys5_pglib1b; multistart = true)

    for use_simulation in (false, true)
        # the following 3 tests all fail when use_simulation is false.
        (decisions1, decisions2) = run_startup_shutdown_obj_fun_test(
            c_sys5_pglib1a,
            c_sys5_pglib2a;
            multistart = true,
            simulation = use_simulation,
        )
        # NOTE not all of the decision types here have >= 1, we'll do another scenario such that we get full decision coverage across both of them:

        (decisions1_2, decisions2_2) = run_startup_shutdown_obj_fun_test(
            c_sys5_pglib1b,
            c_sys5_pglib2b;
            multistart = true,
            simulation = use_simulation,
        )
        @test all(isapprox.(decisions1_2, decisions2_2))
        # Make sure our tests included all types of startups and shutdowns
        @test all(approx_geq_1.(decisions1 .+ decisions1_2))
    end
end

@testset "MarketBidCost incremental ThermalStandard, no time series versus constant time series" begin
    sys_no_ts = load_sys_incr()
    set_name!(sys_no_ts, "thermal_no_ts")
    sys_constant_ts = build_sys_incr(false, false, false)
    set_name!(sys_constant_ts, "thermal_constant_ts")
    test_generic_mbc_equivalence(
        sys_no_ts,
        sys_constant_ts,
    )
end

@testset "MarketBidCost incremental RenewableDispatch, no time series versus constant time series" begin
    sys_no_ts = load_sys_incr()
    sys_constant_ts = build_sys_incr(false, false, false)
    for sys in (sys_no_ts, sys_constant_ts)
        unit1 = get_component(SEL_INCR, sys)
        replace_with_renewable!(sys, unit1; magnitude = 1.0, random_variation = 0.1)
    end
    test_generic_mbc_equivalence(sys_no_ts, sys_constant_ts)
end

# debugging option: change to true to save text files of objective functions for
# certain tests that aren't passing.
const SAVE_FILES = true

for decremental in (false, true)
    adj = decremental ? "decremental" : "incremental"
    build_func = decremental ? build_sys_decr2 : build_sys_incr
    comp_type = decremental ? InterruptiblePowerLoad : ThermalStandard
    device_models = if decremental
        [PowerLoadInterruption, PowerLoadDispatch]
    else
        [ThermalBasicUnitCommitment]
    end
    @testset for dm in device_models
        device_to_formulation =
            Dict{Type{<:Device}, Type{<:PowerSimulations.AbstractDeviceFormulation}}(
                comp_type => dm,
            )
        if has_initial_input(decremental, device_to_formulation)
            @testset "MarketBidCost $(adj) with time varying min gen cost" begin
                baseline = build_func(false, false, false)
                varying = build_func(true, false, false)
                if decremental
                    tweak_for_decremental_initial!(varying)
                    tweak_for_decremental_initial!(baseline)
                end
                for use_simulation in (false, true)
                    in_memory_store_opts = use_simulation ? [false, true] : [false]
                    for in_memory_store in in_memory_store_opts
                        decisions1, decisions2 =
                            run_mbc_obj_fun_test(
                                baseline,
                                varying;
                                is_decremental = decremental,
                                simulation = use_simulation,
                                in_memory_store = in_memory_store,
                                device_to_formulation = device_to_formulation,
                            )
                        if !all(isapprox.(decisions1, decisions2))
                            @show decisions1
                            @show decisions2
                        end
                        @assert all(approx_geq_1.(decisions1))
                    end
                end
            end
        end

        @testset "MarketBidCost $(adj) with time varying slopes" begin
            baseline = build_func(false, false, false)
            varying = build_func(false, false, true)

            set_name!(baseline, "baseline_slopes")
            set_name!(varying, "varying_slopes")

            for use_simulation in (false, true)
                in_memory_store_opts = use_simulation ? [false, true] : [false]
                for in_memory_store in in_memory_store_opts
                    decisions1, decisions2 =
                        run_mbc_obj_fun_test(
                            baseline,
                            varying;
                            is_decremental = decremental,
                            simulation = use_simulation,
                            in_memory_store = in_memory_store,
                            save_obj_fcn = SAVE_FILES,
                            device_to_formulation = device_to_formulation,
                        )
                    if !all(isapprox.(decisions1, decisions2))
                        @show decisions1
                        @show decisions2
                    end
                    @assert all(approx_geq_1.(decisions1))
                end
            end
        end

        @testset "MarketBidCost $(adj) with time varying breakpoints" begin
            baseline = build_func(false, false, false)
            varying = build_func(false, true, false)

            set_name!(baseline, "baseline_breakpoints")
            set_name!(varying, "varying_breakpoints")
            for use_simulation in (false, true)
                in_memory_store_opts = use_simulation ? [false, true] : [false]
                for in_memory_store in in_memory_store_opts
                    decisions1, decisions2 =
                        run_mbc_obj_fun_test(
                            baseline,
                            varying;
                            is_decremental = decremental,
                            simulation = use_simulation,
                            in_memory_store = in_memory_store,
                            save_obj_fcn = SAVE_FILES,
                            device_to_formulation = device_to_formulation,
                        )
                    if !all(isapprox.(decisions1, decisions2))
                        @show decisions1
                        @show decisions2
                    end
                    @assert all(approx_geq_1.(decisions1))
                end
            end
        end

        @testset "MarketBidCost $(adj) with time varying everything" begin
            baseline = build_func(false, false, false)
            varying = build_func(true, true, true)

            for use_simulation in (false, true)
                decisions1, decisions2 =
                    run_mbc_obj_fun_test(
                        baseline,
                        varying;
                        simulation = use_simulation,
                        is_decremental = decremental,
                        device_to_formulation = device_to_formulation,
                    )
                if !all(isapprox.(decisions1, decisions2))
                    @show decisions1
                    @show decisions2
                end
                @assert all(approx_geq_1.(decisions1))
            end
        end

        @testset "MarketBidCost $(adj) with variable number of tranches" begin
            baseline = build_func(true, true, true)
            set_name!(baseline, "baseline_tranches")
            variable_tranches = build_func(true, true, true; create_extra_tranches = true)
            set_name!(variable_tranches, "variable_tranches")
            test_generic_mbc_equivalence(
                baseline,
                variable_tranches;
                save_obj_fcn = SAVE_FILES,
                is_decremental = decremental,
                device_to_formulation = device_to_formulation,
            )
        end
    end
end

@testset "MarketBidCost incremental with heterogeneous time series names" begin
    sel = make_selector(x -> get_operation_cost(x) isa MarketBidCost, ThermalStandard)
    baseline = build_sys_incr(true, true, true; active_components = sel)
    @assert length(get_components(sel, baseline)) == 2

    # Should succeed for varying initial input time series names:
    variable_ii_names = build_sys_incr(
        true,
        true,
        true;
        active_components = sel,
        initial_input_names_vary = true,
    )
    test_generic_mbc_equivalence(baseline, variable_ii_names)

    # Should give an informative error for varying variable cost time series names:
    variable_vc_names = build_sys_incr(
        true,
        true,
        true;
        active_components = sel,
        variable_cost_names_vary = true,
    )
    model = build_generic_mbc_model(variable_vc_names; multistart = false)
    mkpath(test_path)
    PSI.set_output_dir!(model, test_path)
    # Commented out temporarily as the error changed
    # @test_throws "All time series names must be equal" PSI.build_impl!(model)  # see below re: build_impl!
end

@testset "Test some MarketBidCost data validations" begin
    # Test multistart and convexity validation
    nonconvex = build_sys_incr(
        false,
        false,
        false;
        modify_baseline_pwl = pwl -> begin
            y_coords = get_y_coords(pwl)
            y_coords[3] = y_coords[1]
            pwl
        end,
    )
    set_start_up!(
        get_operation_cost(get_component(ThermalStandard, nonconvex, "Test Unit2")),
        (hot = 1.0, warm = 1.5, cold = 2.0),
    )
    model = build_generic_mbc_model(nonconvex; multistart = false)
    # We'll use build_impl! rather than build! to keep PSI's logging configuration from interfering with @test_logs and polluting the test output
    mkpath(test_path)
    PSI.set_output_dir!(model, test_path)
    @test_logs (:warn, r"Multi-start costs detected for non-multi-start unit Test Unit2.*") (
        match_mode = :any
    ) (@test_throws "is non-convex" PSI.build_impl!(model))

    # Test constant P1 validation
    variable_p1 = build_sys_incr(false, true, false; do_override_min_x = false)
    model = build_generic_mbc_model(variable_p1; multistart = false)
    mkpath(test_path)
    PSI.set_output_dir!(model, test_path)
    @test_throws "Inconsistent minimum breakpoint values" PSI.build_impl!(model)
end

@testset "Test 3d results" begin
    # TODO: Test actual values
    varying = build_sys_incr(true, true, true)
    for in_memory_store in (false, true)
        # model1, res1 = run_generic_mbc_sim(baseline)
        model2, res2 = run_generic_mbc_sim(varying; in_memory_store = in_memory_store)
        parameters = read_parameters(res2)
        @test haskey(
            parameters,
            "IncrementalPiecewiseLinearBreakpointParameter__ThermalStandard",
        )
        for df in
            values(
            parameters["IncrementalPiecewiseLinearBreakpointParameter__ThermalStandard"],
        )
            @test names(df) == ["DateTime", "name", "name2", "value"]
        end
        for (key, df) in read_realized_parameters(res2)
            if key in (
                "IncrementalPiecewiseLinearBreakpointParameter__ThermalStandard",
                "IncrementalPiecewiseLinearSlopeParameter__ThermalStandard",
            )
                @test names(df) == ["DateTime", "name", "name2", "value"]
            else
                @test names(df) == ["DateTime", "name", "value"]
            end
        end

        # TODO: Test actual values
    end
end

@testset "concavity check error" begin
    sys = build_system(PSITestSystems, "c_sys5_il")
    load = first(get_components(PSY.InterruptiblePowerLoad, sys))
    selector = make_selector(PSY.InterruptiblePowerLoad, get_name(load))
    non_decr_slopes = [0.13, 0.11, 0.12]  # Non-decreasing slopes (should trigger error)
    x_coords = [0.1, 0.3, 0.6, 1.0]
    pw_curve = PiecewiseIncrementalCurve(0.0, 0.0, x_coords, non_decr_slopes)
    add_mbc_inner!(sys, selector; decr_curve = pw_curve)  # Fixed: pass selector, not slopes

    comp = first(get_components(selector, sys))
    @assert typeof(get_operation_cost(comp)) == PSY.MarketBidCost

    model = build_generic_mbc_model(sys)
    mkpath(test_path)
    PSI.set_output_dir!(model, test_path)
    msg = "ArgumentError: Decremental MarketBidCost for component $(get_name(load)) is non-concave"
    @test_throws msg PSI.build_impl!(model)
end

@testset "MarketBidCost decremental basic: single problem" begin
    sys = build_system(PSITestSystems, "c_sys5_il")
    load = first(get_components(PSY.InterruptiblePowerLoad, sys))
    selector = make_selector(PSY.InterruptiblePowerLoad, get_name(load))
    add_mbc!(sys, selector; incremental = false, decremental = true)
    @assert typeof(get_operation_cost(load)) == PSY.MarketBidCost
    _, res = run_generic_mbc_prob(sys)
end

@testset "MarketBidCost decremental basic: simulation" begin
    sys = build_system(PSITestSystems, "c_sys5_il")
    load = first(get_components(PSY.InterruptiblePowerLoad, sys))
    selector = make_selector(PSY.InterruptiblePowerLoad, get_name(load))
    add_mbc!(sys, selector; incremental = false, decremental = true)
    extend_mbc!(sys, selector)
    op_cost = get_operation_cost(load)
    @assert typeof(op_cost) == PSY.MarketBidCost
    @assert typeof(get_decremental_offer_curves(op_cost)) <: PSY.TimeSeriesKey
    _, res = run_generic_mbc_sim(sys)
end

@testset "MarketBidCost decremental PowerLoadInterruption, no time series vs constant time series" begin
    sys_no_ts = load_sys_decr2()
    sys_constant_ts = build_sys_decr2(false, false, false)
    test_generic_mbc_equivalence(sys_no_ts, sys_constant_ts)
end

# TODO error if there's nonzero decremental initial input for PowerLoadDispatch.
@testset "MarketBidCost decremental PowerLoadDispatch, no time series vs constant time series" begin
    device_to_formulation = Dict{Type{<:PSY.Device}, Type{<:PSI.AbstractDeviceFormulation}}(
        PSY.InterruptiblePowerLoad => PowerLoadDispatch,
    )
    sys_no_ts = load_sys_decr2()
    sys_constant_ts = build_sys_decr2(false, false, false)
    test_generic_mbc_equivalence(
        sys_no_ts,
        sys_constant_ts;
        device_to_formulation = device_to_formulation,
    )
end
