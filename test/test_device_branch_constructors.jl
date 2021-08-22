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

        @test check_variable_bounded(op_problem_m, FlowActivePowerVariable, MonitoredLine)
        @test check_variable_unbounded(op_problem_m, FlowActivePowerVariable, Line)

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
        @test check_flow_variable_values(
            op_problem_m,
            FlowActivePowerVariable,
            MonitoredLine,
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

        @test check_variable_unbounded(op_problem_m, FlowActivePowerVariable, MonitoredLine)
        # Broken
        # @test check_variable_bounded(op_problem_m, FlowActivePowerVariable, Line)

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
        @test check_flow_variable_values(
            op_problem_m,
            FlowActivePowerVariable,
            Line,
            "2",
            1.5,
        )
    end
end

@testset "AC Power Flow Monitored Line Flow Constraints" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    limits = PSY.get_flow_limits(PSY.get_component(MonitoredLine, system, "1"))
    template = get_thermal_dispatch_template_network(ACPPowerModel)
    op_problem_m = OperationsProblem(template, system; optimizer = ipopt_optimizer)
    @test build!(op_problem_m; output_dir = mktempdir(cleanup = true)) ==
          PSI.BuildStatus.BUILT

    @test check_variable_bounded(op_problem_m, FlowActivePowerFromToVariable, MonitoredLine)
    @test check_variable_unbounded(
        op_problem_m,
        FlowReactivePowerFromToVariable,
        MonitoredLine,
    )

    @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
    @test check_flow_variable_values(
        op_problem_m,
        FlowActivePowerFromToVariable,
        FlowReactivePowerFromToVariable,
        MonitoredLine,
        "1",
        0.0,
        limits.from_to,
    )
end

@testset "DC Power Flow Models for HVDCLine with with Line Flow Constraints, TapTransformer & Transformer2W Unbounded" begin
    ratelimit_constraint_keys = [
        PSI.ConstraintKey(RateLimitConstraint, Transformer2W, "ub"),
        PSI.ConstraintKey(RateLimitConstraint, Transformer2W, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, TapTransformer, "ub"),
        PSI.ConstraintKey(RateLimitConstraint, TapTransformer, "lb"),
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

    for model in [DCPPowerModel, StandardPTDFModel],
        hvdc_model in [HVDCDispatch, HVDCLossless]

        template = get_template_dispatch_with_network(model)
        set_device_model!(template, HVDCLine, hvdc_model)
        op_problem_m = OperationsProblem(
            template,
            system;
            optimizer = OSQP_optimizer,
            PTDF = PSY.PTDF(system),
        )
        @test build!(op_problem_m; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT

        @test check_variable_bounded(op_problem_m, FlowActivePowerVariable, HVDCLine)
        @test check_variable_unbounded(
            op_problem_m,
            FlowActivePowerVariable,
            TapTransformer,
        )
        @test check_variable_unbounded(op_problem_m, FlowActivePowerVariable, Transformer2W)

        psi_constraint_test(op_problem_m, ratelimit_constraint_keys)

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

        @test check_flow_variable_values(
            op_problem_m,
            FlowActivePowerVariable,
            HVDCLine,
            "DCLine3",
            limits_min,
            limits_max,
        )
        @test check_flow_variable_values(
            op_problem_m,
            FlowActivePowerVariable,
            TapTransformer,
            "Trans3",
            -rate_limit,
            rate_limit,
        )
        @test check_flow_variable_values(
            op_problem_m,
            FlowActivePowerVariable,
            Transformer2W,
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
            # @test check_variable_unbounded(op_problem_m, FlowActivePowerVariable, HVDCLine)

            @test check_variable_bounded(
                op_problem_m,
                FlowActivePowerVariable,
                TapTransformer,
            )
            @test check_variable_bounded(
                op_problem_m,
                FlowActivePowerVariable,
                TapTransformer,
            )
        end

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

        @test check_flow_variable_values(
            op_problem_m,
            FlowActivePowerVariable,
            HVDCLine,
            "DCLine3",
            limits_min,
            limits_max,
        )
        @test check_flow_variable_values(
            op_problem_m,
            FlowActivePowerVariable,
            TapTransformer,
            "Trans3",
            -rate_limit,
            rate_limit,
        )
        @test check_flow_variable_values(
            op_problem_m,
            FlowActivePowerVariable,
            Transformer2W,
            "Trans4",
            -rate_limit2w,
            rate_limit2w,
        )
    end
end

@testset "AC Power Flow Models for HVDCLine Flow Constraints and TapTransformer & Transformer2W Unbounded" begin
    ratelimit_constraint_keys = [
        PSI.ConstraintKey(RateLimitFTConstraint, Transformer2W),
        PSI.ConstraintKey(RateLimitTFConstraint, Transformer2W),
        PSI.ConstraintKey(RateLimitFTConstraint, TapTransformer),
        PSI.ConstraintKey(RateLimitTFConstraint, TapTransformer),
        PSI.ConstraintKey(FlowRateConstraintFT, HVDCLine),
        PSI.ConstraintKey(FlowRateConstraintTF, HVDCLine),
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
    set_device_model!(template, DeviceModel(HVDCLine, HVDCDispatch))
    op_problem_m = OperationsProblem(template, system; optimizer = ipopt_optimizer)
    @test build!(op_problem_m; output_dir = mktempdir(cleanup = true)) ==
          PSI.BuildStatus.BUILT

    check_variable_bounded(op_problem_m, FlowReactivePowerToFromVariable, HVDCLine)
    check_variable_bounded(op_problem_m, FlowActivePowerVariable, HVDCLine)
    @test check_variable_bounded(
        op_problem_m,
        FlowActivePowerFromToVariable,
        TapTransformer,
    )
    @test check_variable_unbounded(
        op_problem_m,
        FlowReactivePowerFromToVariable,
        TapTransformer,
    )
    @test check_variable_bounded(op_problem_m, FlowActivePowerToFromVariable, Transformer2W)
    @test check_variable_unbounded(
        op_problem_m,
        FlowReactivePowerToFromVariable,
        Transformer2W,
    )

    psi_constraint_test(op_problem_m, ratelimit_constraint_keys)

    @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

    @test check_flow_variable_values(
        op_problem_m,
        FlowActivePowerVariable,
        FlowReactivePowerToFromVariable,
        HVDCLine,
        "DCLine3",
        limits_max,
    )
    @test check_flow_variable_values(
        op_problem_m,
        FlowActivePowerFromToVariable,
        FlowReactivePowerFromToVariable,
        TapTransformer,
        "Trans3",
        rate_limit,
    )
    @test check_flow_variable_values(
        op_problem_m,
        FlowActivePowerToFromVariable,
        FlowReactivePowerToFromVariable,
        Transformer2W,
        "Trans4",
        rate_limit2w,
    )
end

#= This Test is Broken to do a missing implementation of add_variable
@testset "DC Power Flow Models for HVDCLine Dispatch and TapTransformer & Transformer2W Unbounded" begin
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

    template = get_template_dispatch_with_network(StandardPTDFModel)
    set_device_model!(template, DeviceModel(HVDCLine, HVDCDispatch))
    op_problem_m = OperationsProblem(template, system; PTDF = PSY.PTDF(system), optimizer = ipopt_optimizer)
    @test build!(op_problem_m; output_dir = mktempdir(cleanup = true)) ==
          PSI.BuildStatus.BUILT

    check_variable_bounded(op_problem_m, FlowReactivePowerToFromVariable,HVDCLine)
    check_variable_bounded(op_problem_m, FlowActivePowerToFromVariable,HVDCLine)
    @test check_variable_bounded(op_problem_m, FlowActivePowerFromToVariable,TapTransformer)
    @test check_variable_unbounded(op_problem_m, FlowReactivePowerFromToVariable,TapTransformer)
    @test check_variable_bounded(op_problem_m, FlowActivePowerToFromVariable,Transformer2W)
    @test check_variable_unbounded(op_problem_m, FlowReactivePowerToFromVariable,Transformer2W)

    psi_constraint_test(op_problem_m, ratelimit_constraint_names)

    @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

    @test check_flow_variable_values(
        op_problem_m,
        FlowActivePowerToFromVariable,HVDCLine,
        FlowReactivePowerToFromVariable,HVDCLine,
        "DCLine3",
        limits_max,
    )
    @test check_flow_variable_values(
        op_problem_m,
        FlowActivePowerFromToVariable,TapTransformer,
        FlowReactivePowerFromToVariable,TapTransformer,
        "Trans3",
        rate_limit,
    )
    @test check_flow_variable_values(
        op_problem_m,
        FlowActivePowerToFromVariable,Transformer2W,
        FlowReactivePowerToFromVariable,Transformer2W,
        "Trans4",
        rate_limit2w,
    )
end
=#
