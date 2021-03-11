@testset "DC Power Flow Models Monitored Line Flow Constraints and Static Unbounded" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    limits = PSY.get_flow_limits(PSY.get_component(MonitoredLine, system, "1"))
    for model in [DCPPowerModel, StandardPTDFModel]
        template = get_thermal_dispatch_template_network(model)
        op_problem_m = OperationsProblem(
            template,
            system;
            optimizer = OSQP_optimizer,
            PTDF = PSY.PTDF(system),
        )
        @test build!(op_problem_m; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT

        @test check_variable_bounded(op_problem_m, :Fp__MonitoredLine)
        @test check_variable_unbounded(op_problem_m, :Fp__Line)

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
        @test check_flow_variable_values(
            op_problem_m,
            :Fp__MonitoredLine,
            "1",
            limits.from_to,
        )
    end
end

@testset "DC Power Flow Models Monitored Line Flow Constraints and Static with Bounds" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    set_rate!(PSY.get_component(Line, system, "2"), 1.5)
    for model in [DCPPowerModel, StandardPTDFModel]
        template = get_thermal_dispatch_template_network(model)
        set_device_model!(template, DeviceModel(Line, StaticBranch))
        set_device_model!(template, DeviceModel(MonitoredLine, StaticBranchUnbounded))
        op_problem_m = OperationsProblem(
            template,
            system;
            optimizer = OSQP_optimizer,
            PTDF = PSY.PTDF(system),
        )
        @test build!(op_problem_m; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT

        @test check_variable_unbounded(op_problem_m, :Fp__MonitoredLine)
        # Broken
        # @test check_variable_bounded(op_problem_m, :Fp__Line)

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
        @test check_flow_variable_values(op_problem_m, :Fp__Line, "2", 1.5)
    end
end

@testset "AC Power Flow Monitored Line Flow Constraints" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    limits = PSY.get_flow_limits(PSY.get_component(MonitoredLine, system, "1"))
    template = get_thermal_dispatch_template_network(ACPPowerModel)
    op_problem_m = OperationsProblem(template, system; optimizer = ipopt_optimizer)
    @test build!(op_problem_m; output_dir = mktempdir(cleanup = true)) ==
          PSI.BuildStatus.BUILT

    @test check_variable_bounded(op_problem_m, :FpFT__MonitoredLine)
    @test check_variable_unbounded(op_problem_m, :FqFT__MonitoredLine)

    @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
    @test check_flow_variable_values(
        op_problem_m,
        :FpFT__MonitoredLine,
        :FqFT__MonitoredLine,
        "1",
        0.0,
        limits.from_to,
    )
end

@testset "DC Power Flow Models for HVDCLine with with Line Flow Constraints, TapTransformer & Transformer2W Unbounded" begin
    ratelimit_constraint_names = [
        :RateLimit_ub__Transformer2W,
        :RateLimit_lb__Transformer2W,
        :RateLimit_ub__TapTransformer,
        :RateLimit_lb__TapTransformer,
    ]

    system = PSB.build_system(PSITestSystems, "c_sys14_dc")
    hvdc_line = PSY.get_component(HVDCLine, system, "DCLine3")
    limits_from = PSY.get_active_power_limits_from(hvdc_line)
    limits_to = PSY.get_active_power_limits_to(hvdc_line)
    limits_min = min(limits_from.min, limits_to.min)
    limits_max = min(limits_from.max, limits_to.max)

    tap_transformer = PSY.get_component(TapTransformer, system, "Trans3")
    rate_limit = PSY.get_rate(tap_transformer)

    transformer = PSY.get_component(Transformer2W, system, "Trans4")
    rate_limit2w = PSY.get_rate(tap_transformer)

    for model in [DCPPowerModel, StandardPTDFModel]
        template = get_template_dispatch_with_network(model)
        op_problem_m = OperationsProblem(
            template,
            system;
            optimizer = OSQP_optimizer,
            PTDF = PSY.PTDF(system),
        )
        @test build!(op_problem_m; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT

        if model == DCPPowerModel
            @test check_variable_bounded(op_problem_m, :Fp__HVDCLine)
            @test check_variable_unbounded(op_problem_m, :Fp__TapTransformer)
            @test check_variable_unbounded(op_problem_m, :Fp__Transformer2W)
        end

        psi_constraint_test(op_problem_m, ratelimit_constraint_names)

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

        @test check_flow_variable_values(
            op_problem_m,
            :Fp__HVDCLine,
            "DCLine3",
            limits_min,
            limits_max,
        )
        @test check_flow_variable_values(
            op_problem_m,
            :Fp__TapTransformer,
            "Trans3",
            -rate_limit,
            rate_limit,
        )
        @test check_flow_variable_values(
            op_problem_m,
            :Fp__Transformer2W,
            "Trans4",
            -rate_limit2w,
            rate_limit2w,
        )
    end
end

@testset "DC Power Flow Models for Unbounded HVDCLine, and StaticBranchBounds for TapTransformer & Transformer2W" begin
    system = PSB.build_system(PSITestSystems, "c_sys14_dc")
    hvdc_line = PSY.get_component(HVDCLine, system, "DCLine3")
    limits_from = PSY.get_active_power_limits_from(hvdc_line)
    limits_to = PSY.get_active_power_limits_to(hvdc_line)
    limits_min = min(limits_from.min, limits_to.min)
    limits_max = min(limits_from.max, limits_to.max)

    tap_transformer = PSY.get_component(TapTransformer, system, "Trans3")
    rate_limit = PSY.get_rate(tap_transformer)

    transformer = PSY.get_component(Transformer2W, system, "Trans4")
    rate_limit2w = PSY.get_rate(tap_transformer)

    for model in [DCPPowerModel, StandardPTDFModel]
        template = get_template_dispatch_with_network(model)
        set_device_model!(template, DeviceModel(HVDCLine, HVDCUnbounded))
        set_device_model!(template, DeviceModel(TapTransformer, StaticBranchBounds))
        set_device_model!(template, DeviceModel(Transformer2W, StaticBranchBounds))
        op_problem_m = OperationsProblem(
            template,
            system;
            optimizer = OSQP_optimizer,
            PTDF = PSY.PTDF(system),
        )
        @test build!(op_problem_m; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT

        if model == DCPPowerModel
            # TODO: Currently Broken, remove variable bounds in HVDCUnbounded
            # @test check_variable_unbounded(op_problem_m, :Fp__HVDCLine)

            @test check_variable_bounded(op_problem_m, :Fp__TapTransformer)
            @test check_variable_bounded(op_problem_m, :Fp__TapTransformer)
        end

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

        @test check_flow_variable_values(
            op_problem_m,
            :Fp__HVDCLine,
            "DCLine3",
            limits_min,
            limits_max,
        )
        @test check_flow_variable_values(
            op_problem_m,
            :Fp__TapTransformer,
            "Trans3",
            -rate_limit,
            rate_limit,
        )
        @test check_flow_variable_values(
            op_problem_m,
            :Fp__Transformer2W,
            "Trans4",
            -rate_limit2w,
            rate_limit2w,
        )
    end
end

@testset "AC Power Flow Models for HVDCLine Flow Constraints and TapTransformer & Transformer2W Unbounded" begin
    ratelimit_constraint_names = [
        :RateLimitFT__Transformer2W,
        :RateLimitTF__Transformer2W,
        :RateLimitFT__TapTransformer,
        :RateLimitTF__TapTransformer,
        :RateLimitFT__HVDCLine,
        :RateLimitTF__HVDCLine,
    ]

    system = PSB.build_system(PSITestSystems, "c_sys14_dc")

    hvdc_line = PSY.get_component(HVDCLine, system, "DCLine3")
    limits_from = PSY.get_active_power_limits_from(hvdc_line)
    limits_to = PSY.get_active_power_limits_to(hvdc_line)
    limits_min = min(limits_from.min, limits_to.min)
    limits_max = min(limits_from.max, limits_to.max)

    tap_transformer = PSY.get_component(TapTransformer, system, "Trans3")
    rate_limit = PSY.get_rate(tap_transformer)

    transformer = PSY.get_component(Transformer2W, system, "Trans4")
    rate_limit2w = PSY.get_rate(tap_transformer)

    template = get_template_dispatch_with_network(ACPPowerModel)
    op_problem_m = OperationsProblem(template, system; optimizer = ipopt_optimizer)
    @test build!(op_problem_m; output_dir = mktempdir(cleanup = true)) ==
          PSI.BuildStatus.BUILT

    check_variable_bounded(op_problem_m, :FqTF__HVDCLine)
    check_variable_bounded(op_problem_m, :FpTF__HVDCLine)
    @test check_variable_bounded(op_problem_m, :FpFT__TapTransformer)
    @test check_variable_unbounded(op_problem_m, :FqFT__TapTransformer)
    @test check_variable_bounded(op_problem_m, :FpTF__Transformer2W)
    @test check_variable_unbounded(op_problem_m, :FqTF__Transformer2W)

    psi_constraint_test(op_problem_m, ratelimit_constraint_names)

    @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

    @test check_flow_variable_values(
        op_problem_m,
        :FpTF__HVDCLine,
        :FqTF__HVDCLine,
        "DCLine3",
        limits_max,
    )
    @test check_flow_variable_values(
        op_problem_m,
        :FpFT__TapTransformer,
        :FqFT__TapTransformer,
        "Trans3",
        rate_limit,
    )
    @test check_flow_variable_values(
        op_problem_m,
        :FpTF__Transformer2W,
        :FqTF__Transformer2W,
        "Trans4",
        rate_limit2w,
    )
end
