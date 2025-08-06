function _make_5_bus_with_import_export()
    sys = build_system(PSITestSystems, "c_sys5_uc")

    source = Source(;
        name = "source",
        available = true,
        bus = get_component(ACBus, sys, "nodeC"),
        active_power = 0.0,
        reactive_power = 0.0,
        active_power_limits = (min = -2.0, max = 2.0),
        reactive_power_limits = (min = -2.0, max = 2.0),
        R_th = 0.01,
        X_th = 0.02,
        internal_voltage = 1.0,
        internal_angle = 0.0,
        base_power = 100.0,
    )

    import_curve = make_import_curve(
        [0.0, 100.0, 105.0, 120.0, 200.0],
        [5.0, 10.0, 20.0, 40.0],
    )

    export_curve = make_export_curve(
        [0.0, 100.0, 105.0, 120.0, 200.0],
        [12.0, 8.0, 4.0, 0.0],
    )

    ie_cost = ImportExportCost(;
        import_offer_curves = import_curve,
        export_offer_curves = export_curve,
        ancillary_service_offers = Vector{Service}(),
        energy_import_weekly_limit = 1e6,
        energy_export_weekly_limit = 1e6,
    )

    set_operation_cost!(source, ie_cost)
    add_component!(sys, source)
    return sys
end
@testset "ImportExportSource Source With CopperPlate" begin
    constraint_keys = [
        PSI.ConstraintKey(ImportExportBudgetConstraint, PSY.Source, "import"),
        PSI.ConstraintKey(ImportExportBudgetConstraint, PSY.Source, "export"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.Source, "ub"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.Source, "lb"),
        PSI.ConstraintKey(PieceWiseLinearBlockOfferConstraint, PSY.Source),
        PSI.ConstraintKey(PieceWiseLinearBlockDecrementalOfferConstraint, PSY.Source),
    ]

    sys = _make_5_bus_with_import_export()

    model = DecisionModel(MockOperationProblem, CopperPlatePowerModel, sys)
    device_model = DeviceModel(Source, ImportExportSourceModel)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 218, 24, 48, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "ImportExportSource Source With ACPPowerModel" begin
    constraint_keys = [
        PSI.ConstraintKey(ImportExportBudgetConstraint, PSY.Source, "import"),
        PSI.ConstraintKey(ImportExportBudgetConstraint, PSY.Source, "export"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.Source, "ub"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.Source, "lb"),
        PSI.ConstraintKey(PieceWiseLinearBlockOfferConstraint, PSY.Source),
        PSI.ConstraintKey(PieceWiseLinearBlockDecrementalOfferConstraint, PSY.Source),
    ]

    sys = _make_5_bus_with_import_export()
    model = DecisionModel(MockOperationProblem, ACPPowerModel, sys)
    device_model = DeviceModel(Source, ImportExportSourceModel)
    mock_construct_device!(model, device_model)
    moi_tests(model, 264, 0, 242, 48, 48, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "ImportExportSource Source With CopperPlate and TimeSeries" begin
    constraint_keys = [
        PSI.ConstraintKey(ImportExportBudgetConstraint, PSY.Source, "import"),
        PSI.ConstraintKey(ImportExportBudgetConstraint, PSY.Source, "export"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.Source, "ub"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.Source, "lb"),
        PSI.ConstraintKey(PieceWiseLinearBlockOfferConstraint, PSY.Source),
        PSI.ConstraintKey(PieceWiseLinearBlockDecrementalOfferConstraint, PSY.Source),
    ]

    sys = _make_5_bus_with_import_export()
    source = get_component(Source, sys, "source")

    load = first(get_components(PowerLoad, sys))
    tstamp =
        TimeSeries.timestamp(get_time_series_array(Deterministic, load, "max_active_power"))
    tstamp = vcat(tstamp, tstamp .+ Hour(24))

    day_data = [
        0.9, 0.85, 0.95, 0.2, 0.0, 0.0,
        0.9, 0.85, 0.95, 0.2, 0.0, 0.0,
        0.9, 0.85, 0.95, 0.2, 0.0, 0.0,
        0.9, 0.85, 0.95, 0.2, 0.0, 0.0,
    ]

    ts_data = repeat(day_data, 2)
    ts_out = SingleTimeSeries(
        "max_active_power_out",
        TimeArray(tstamp, ts_data);
        scaling_factor_multiplier = get_max_active_power,
    )
    ts_in = SingleTimeSeries(
        "max_active_power_in",
        TimeArray(tstamp, ts_data);
        scaling_factor_multiplier = get_max_active_power,
    )
    add_time_series!(sys, source, ts_out)
    add_time_series!(sys, source, ts_in)
    transform_single_time_series!(sys, Hour(24), Hour(24))

    template = ProblemTemplate(NetworkModel(CopperPlatePowerModel))
    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    source_model = DeviceModel(
        Source,
        ImportExportSourceModel;
        time_series_names = Dict{Any, String}(
            ActivePowerInTimeSeriesParameter => "max_active_power_in",
            ActivePowerOutTimeSeriesParameter => "max_active_power_out",
        ),
    )
    set_device_model!(template, source_model)

    model = DecisionModel(
        template,
        sys;
        name = "UC",
        optimizer = HiGHS_optimizer,
        store_variable_names = true,
        optimizer_solve_log_print = false,
    )

    @test build!(model; output_dir = mktempdir()) == PSI.ModelBuildStatus.BUILT
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    res = OptimizationProblemResults(model)
    p_out = read_variable(res, "ActivePowerOutVariable__Source")[!, 2]
    p_in = read_variable(res, "ActivePowerInVariable__Source")[!, 2]

    # Test that is zero when the time series is zero
    @test p_out[5] == 0.0
    @test p_in[5] == 0.0
    @test p_out[6] == 0.0
    @test p_in[6] == 0.0
end

@testset "ImportExportSource Source With CopperPlate and TimeSeries" begin
    constraint_keys = [
        PSI.ConstraintKey(ImportExportBudgetConstraint, PSY.Source, "import"),
        PSI.ConstraintKey(ImportExportBudgetConstraint, PSY.Source, "export"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.Source, "ub"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.Source, "lb"),
        PSI.ConstraintKey(PieceWiseLinearBlockOfferConstraint, PSY.Source),
        PSI.ConstraintKey(PieceWiseLinearBlockDecrementalOfferConstraint, PSY.Source),
        PSI.ConstraintKey(ActivePowerOutVariableTimeSeriesLimitsConstraint, Source, "ub"),
        PSI.ConstraintKey(ActivePowerInVariableTimeSeriesLimitsConstraint, Source, "ub"),
    ]

    sys = _make_5_bus_with_import_export()
    source = get_component(Source, sys, "source")

    load = first(get_components(PowerLoad, sys))
    tstamp =
        TimeSeries.timestamp(get_time_series_array(Deterministic, load, "max_active_power"))
    tstamp = vcat(tstamp, tstamp .+ Hour(24))

    day_data = [
        0.9, 0.85, 0.95, 0.2, 0.0, 0.0,
        0.9, 0.85, 0.95, 0.2, 0.0, 0.0,
        0.9, 0.85, 0.95, 0.2, 0.0, 0.0,
        0.9, 0.85, 0.95, 0.2, 0.0, 0.0,
    ]

    ts_data = repeat(day_data, 2)
    ts_out = SingleTimeSeries(
        "max_active_power_out",
        TimeArray(tstamp, ts_data);
        scaling_factor_multiplier = get_max_active_power,
    )
    ts_in = SingleTimeSeries(
        "max_active_power_in",
        TimeArray(tstamp, ts_data);
        scaling_factor_multiplier = get_max_active_power,
    )
    add_time_series!(sys, source, ts_out)
    add_time_series!(sys, source, ts_in)
    transform_single_time_series!(sys, Hour(24), Hour(24))

    model = DecisionModel(MockOperationProblem, ACPPowerModel, sys)
    device_model = DeviceModel(
        Source,
        ImportExportSourceModel;
        time_series_names = Dict{Any, String}(
            ActivePowerInTimeSeriesParameter => "max_active_power_in",
            ActivePowerOutTimeSeriesParameter => "max_active_power_out",
        ),
    )
    mock_construct_device!(model, device_model)
    moi_tests(model, 264, 0, 290, 48, 48, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end
