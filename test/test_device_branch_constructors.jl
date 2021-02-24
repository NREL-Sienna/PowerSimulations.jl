@testset "DC Power Flow Models Monitored Line Flow Constraints and Static Unbounded" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    line = PSY.get_component(Line, system, "1")
    PSY.convert_component!(MonitoredLine, line, system)
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
        # TODO: use accessors to remove the use of Symbols Directly
        monitored_line_variable = PSI.get_variable(
            op_problem_m.internal.optimization_container,
            :Fp__MonitoredLine,
        )
        static_line_variable =
            PSI.get_variable(op_problem_m.internal.optimization_container, :Fp__Line)

        @test check_variable_bounded(op_problem_m, :Fp__MonitoredLine)
        @test check_variable_unbounded(op_problem_m, :Fp__Line)

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
        @test check_flow_variable_values(op_problem_m, :Fp__MonitoredLine, "1", limits.from_to)
    end
end

@testset "DC Power Flow Models Monitored Line Flow Constraints and Static with Bounds" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    line = PSY.get_component(Line, system, "1")
    PSY.convert_component!(MonitoredLine, line, system)
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
        # TODO: use accessors to remove the use of Symbols Directly
        monitored_line_variable = PSI.get_variable(
            op_problem_m.internal.optimization_container,
            :Fp__MonitoredLine,
        )
        static_line_variable =
            PSI.get_variable(op_problem_m.internal.optimization_container, :Fp__Line)

        @test check_variable_unbounded(op_problem_m, :Fp__MonitoredLine)
        # Broken
        # @test check_variable_bounded(op_problem_m, :Fp__MonitoredLine)

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
        @test check_flow_variable_values(op_problem_m, :Fp__Line, "2", 1.5)
    end
end

@testset "AC Power Flow Monitored Line Flow Constraints" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    line = PSY.get_component(Line, system, "1")
    PSY.convert_component!(MonitoredLine, line, system)
    limits = PSY.get_flow_limits(PSY.get_component(MonitoredLine, system, "1"))
    template = get_thermal_dispatch_template_network(ACPPowerModel)
    op_problem_m = OperationsProblem(
        template,
        system;
        optimizer = ipopt_optimizer,
    )
    @test build!(op_problem_m; output_dir = mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT

    qFT_line_variable = PSI.get_variable(
        op_problem_m.internal.optimization_container,
        :FqFT__MonitoredLine,
    )
    pFT_line_variable =
        PSI.get_variable(op_problem_m.internal.optimization_container, 
        :FpFT__MonitoredLine
    )

    @test check_variable_bounded(op_problem_m, :FpFT__MonitoredLine)
    @test check_variable_unbounded(op_problem_m, :FqFT__MonitoredLine)


    @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
    fq = JuMP.value(qFT_line_variable["1", 1])
    fp = JuMP.value(pFT_line_variable["1", 1])
    flow = sqrt((fp)^2 + (fq)^2)
    @test isapprox(flow, limits.from_to, atol = 1e-2)
    # TODO: investigate why this test fails beyond the 1st period
    # @test check_flow_variable_values(op_problem_m, :FpFT__MonitoredLine, :FqFT__MonitoredLine, "1", 0.0, limits.from_to,)
end


###
@testset "DC Power Flow Models Monitored Line Flow Constraints and Static Unbounded" begin

    ratelimit_constraint_names = [
        :RateLimit_ub__Transformer2W, :RateLimit_lb__Transformer2W,
        :RateLimit_ub__TapTransformer, :RateLimit_lb__TapTransformer,
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
        # TODO: use accessors to remove the use of Symbols Directly
        hvdc_line_variable = PSI.get_variable(
            op_problem_m.internal.optimization_container,
            :Fp__HVDCLine,
        )
        tap_transformer_variable = PSI.get_variable(
            op_problem_m.internal.optimization_container,
            :Fp__TapTransformer,
        )
        transformer_variable = PSI.get_variable(
            op_problem_m.internal.optimization_container,
            :Fp__Transformer2W,
        )
        if  model == DCPPowerModel
            @test check_variable_bounded(op_problem_m, :Fp__HVDCLine)
            @test check_variable_unbounded(op_problem_m, :Fp__TapTransformer)
            @test check_variable_unbounded(op_problem_m, :Fp__Transformer2W)
        end

        psi_constraint_test(op_problem_m, ratelimit_constraint_names)

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

        @test check_flow_variable_values(op_problem_m, :Fp__HVDCLine, "DCLine3", limits_min, limits_max)
        @test check_flow_variable_values(op_problem_m, :Fp__TapTransformer, "Trans3", -rate_limit, rate_limit)
        @test check_flow_variable_values(op_problem_m, :Fp__Transformer2W, "Trans4", -rate_limit2w, rate_limit2w)
    end
end

@testset "DC Power Flow Models Monitored Line Flow Constraints and Static Unbounded" begin

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
        # TODO: use accessors to remove the use of Symbols Directly
        hvdc_line_variable = PSI.get_variable(
            op_problem_m.internal.optimization_container,
            :Fp__HVDCLine,
        )
        tap_transformer_variable = PSI.get_variable(
            op_problem_m.internal.optimization_container,
            :Fp__TapTransformer,
        )
        transformer_variable = PSI.get_variable(
            op_problem_m.internal.optimization_container,
            :Fp__Transformer2W,
        )
        if  model == DCPPowerModel
            # TODO: Currently Broken, remove variable bounds in HVDCUnbounded
            # @test check_variable_unbounded(op_problem_m, :Fp__HVDCLine)

            @test check_variable_bounded(op_problem_m, :Fp__TapTransformer)
            @test check_variable_bounded(op_problem_m, :Fp__TapTransformer)
        end

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

        @test check_flow_variable_values(op_problem_m, :Fp__HVDCLine, "DCLine3", limits_min, limits_max)
        @test check_flow_variable_values(op_problem_m, :Fp__TapTransformer, "Trans3", -rate_limit, rate_limit)
        @test check_flow_variable_values(op_problem_m, :Fp__Transformer2W, "Trans4", -rate_limit2w, rate_limit2w)
    end
end



@testset "AC Power Flow Models Monitored Line Flow Constraints and Static Unbounded" begin

    ratelimit_constraint_names = [
        :RateLimitFT__Transformer2W, :RateLimitTF__Transformer2W,
        :RateLimitFT__TapTransformer, :RateLimitTF__TapTransformer,
        :RateLimitFT__HVDCLine, :RateLimitTF__HVDCLine,
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
    op_problem_m = OperationsProblem(
        template,
        system;
        optimizer = ipopt_optimizer,
    )
    @test build!(op_problem_m; output_dir = mktempdir(cleanup = true)) ==
            PSI.BuildStatus.BUILT
    # TODO: use accessors to remove the use of Symbols Directly
    qFT_line_variable = PSI.get_variable(
        op_problem_m.internal.optimization_container,
        :FqTF__HVDCLine,
    )
    pFT_line_variable = PSI.get_variable(
        op_problem_m.internal.optimization_container,
        :FpFT__HVDCLine,
    )
    
    qFT_tap_variable = PSI.get_variable(
        op_problem_m.internal.optimization_container,
        :FqFT__TapTransformer,
    )
    pFT_tap_variable = PSI.get_variable(
        op_problem_m.internal.optimization_container,
        :FpFT__TapTransformer,
    )

    qFT_transformer_variable = PSI.get_variable(
        op_problem_m.internal.optimization_container,
        :FqTF__Transformer2W,
    )
    pFT_transformer_variable = PSI.get_variable(
        op_problem_m.internal.optimization_container,
        :FpTF__Transformer2W,
    )

    check_variable_bounded(op_problem_m, :FqTF__HVDCLine)
    check_variable_bounded(op_problem_m, :FpTF__HVDCLine)
    @test check_variable_bounded(op_problem_m, :FpFT__TapTransformer)
    @test check_variable_unbounded(op_problem_m, :FqFT__TapTransformer)
    @test check_variable_bounded(op_problem_m, :FpTF__Transformer2W)
    @test check_variable_unbounded(op_problem_m, :FqTF__Transformer2W)

    psi_constraint_test(op_problem_m, ratelimit_constraint_names)

    @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

    @test check_flow_variable_values(op_problem_m, :FpTF__HVDCLine, :FqTF__HVDCLine, "DCLine3", limits_min, limits_max)
    @test check_flow_variable_values(op_problem_m, :FpFT__TapTransformer, :FqFT__TapTransformer, "Trans3", rate_limit)
    @test check_flow_variable_values(op_problem_m, :FpTF__Transformer2W, :FqTF__Transformer2W, "Trans4", rate_limit2w)
end
