@testset "DC Power Flow Models Monitored Line Flow Constraints and Static Unbounded" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    limits = PSY.get_flow_limits(PSY.get_component(MonitoredLine, system, "1"))
    for model in [DCPPowerModel, PTDFPowerModel]
        template = get_thermal_dispatch_template_network(
            NetworkModel(model; PTDF_matrix = PTDF(system)),
        )
        model_m = DecisionModel(template, system; optimizer = HiGHS_optimizer)
        @test build!(model_m; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT
        @test check_variable_bounded(model_m, FlowActivePowerVariable, MonitoredLine)
        @test check_variable_unbounded(model_m, FlowActivePowerVariable, Line)

        @test solve!(model_m) == RunStatus.SUCCESSFUL
        @test check_flow_variable_values(
            model_m,
            FlowActivePowerVariable,
            MonitoredLine,
            "1",
            limits.from_to,
        )
    end
end

@testset "AC Power Flow Monitored Line Flow Constraints" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    limits = PSY.get_flow_limits(PSY.get_component(MonitoredLine, system, "1"))
    template = get_thermal_dispatch_template_network(ACPPowerModel)
    model_m = DecisionModel(template, system; optimizer = ipopt_optimizer)
    @test build!(model_m; output_dir = mktempdir(; cleanup = true)) == PSI.BuildStatus.BUILT

    @test check_variable_bounded(model_m, FlowActivePowerFromToVariable, MonitoredLine)
    @test check_variable_unbounded(model_m, FlowReactivePowerFromToVariable, MonitoredLine)

    @test solve!(model_m) == RunStatus.SUCCESSFUL
    @test check_flow_variable_values(
        model_m,
        FlowActivePowerFromToVariable,
        FlowReactivePowerFromToVariable,
        MonitoredLine,
        "1",
        0.0,
        limits.from_to,
    )
end

@testset "DC Power Flow Models Monitored Line Flow Constraints and Static with inequalities" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    set_rate!(PSY.get_component(Line, system, "2"), 1.5)
    for model in [DCPPowerModel, PTDFPowerModel]
        template = get_thermal_dispatch_template_network(
            NetworkModel(model; PTDF_matrix = PTDF(system)),
        )
        set_device_model!(template, DeviceModel(Line, StaticBranch))
        set_device_model!(template, DeviceModel(MonitoredLine, StaticBranchUnbounded))
        model_m = DecisionModel(template, system; optimizer = HiGHS_optimizer)
        @test build!(model_m; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT

        @test check_variable_unbounded(model_m, FlowActivePowerVariable, MonitoredLine)

        @test solve!(model_m) == RunStatus.SUCCESSFUL
        @test check_flow_variable_values(model_m, FlowActivePowerVariable, Line, "2", 1.5)
    end
end

@testset "DC Power Flow Models Monitored Line Flow Constraints and Static with Bounds" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    set_rate!(PSY.get_component(Line, system, "2"), 1.5)
    for model in [DCPPowerModel, PTDFPowerModel]
        template = get_thermal_dispatch_template_network(
            NetworkModel(model; PTDF_matrix = PTDF(system)),
        )
        set_device_model!(template, DeviceModel(Line, StaticBranchBounds))
        set_device_model!(template, DeviceModel(MonitoredLine, StaticBranchUnbounded))
        model_m = DecisionModel(template, system; optimizer = HiGHS_optimizer)
        @test build!(model_m; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT

        @test check_variable_unbounded(model_m, FlowActivePowerVariable, MonitoredLine)
        @test check_variable_bounded(model_m, FlowActivePowerVariable, Line)

        @test solve!(model_m) == RunStatus.SUCCESSFUL
        @test check_flow_variable_values(model_m, FlowActivePowerVariable, Line, "2", 1.5)
    end
end

@testset "DC Power Flow Models for TwoTerminalHVDCLine  with with Line Flow Constraints, TapTransformer & Transformer2W Unbounded" begin
    ratelimit_constraint_keys = [
        PSI.ConstraintKey(RateLimitConstraint, Transformer2W, "ub"),
        PSI.ConstraintKey(RateLimitConstraint, Transformer2W, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, TapTransformer, "ub"),
        PSI.ConstraintKey(RateLimitConstraint, TapTransformer, "lb"),
    ]

    system = PSB.build_system(PSITestSystems, "c_sys14_dc")
    hvdc_line = PSY.get_component(TwoTerminalHVDCLine, system, "DCLine3")
    limits_from = PSY.get_active_power_limits_from(hvdc_line)
    limits_to = PSY.get_active_power_limits_to(hvdc_line)
    limits_min = min(limits_from.min, limits_to.min)
    limits_max = min(limits_from.max, limits_to.max)

    tap_transformer = PSY.get_component(TapTransformer, system, "Trans3")
    rate_limit = PSY.get_rate(tap_transformer)

    transformer = PSY.get_component(Transformer2W, system, "Trans4")
    rate_limit2w = PSY.get_rate(tap_transformer)

    for model in [DCPPowerModel, PTDFPowerModel]
        template = get_template_dispatch_with_network(
            NetworkModel(model; PTDF_matrix = PTDF(system)),
        )
        set_device_model!(template, TwoTerminalHVDCLine, HVDCTwoTerminalLossless)
        model_m = DecisionModel(template, system; optimizer = ipopt_optimizer)
        @test build!(model_m; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT

        @test check_variable_unbounded(model_m, FlowActivePowerVariable, TapTransformer)
        @test check_variable_unbounded(model_m, FlowActivePowerVariable, Transformer2W)

        psi_constraint_test(model_m, ratelimit_constraint_keys)

        @test solve!(model_m) == RunStatus.SUCCESSFUL

        @test check_flow_variable_values(
            model_m,
            FlowActivePowerVariable,
            TwoTerminalHVDCLine,
            "DCLine3",
            limits_min,
            limits_max,
        )
        @test check_flow_variable_values(
            model_m,
            FlowActivePowerVariable,
            TapTransformer,
            "Trans3",
            -rate_limit,
            rate_limit,
        )
        @test check_flow_variable_values(
            model_m,
            FlowActivePowerVariable,
            Transformer2W,
            "Trans4",
            -rate_limit2w,
            rate_limit2w,
        )
    end
end

@testset "DC Power Flow Models for Unbounded TwoTerminalHVDCLine , and StaticBranchBounds for TapTransformer & Transformer2W" begin
    system = PSB.build_system(PSITestSystems, "c_sys14_dc")
    hvdc_line = PSY.get_component(TwoTerminalHVDCLine, system, "DCLine3")
    limits_from = PSY.get_active_power_limits_from(hvdc_line)
    limits_to = PSY.get_active_power_limits_to(hvdc_line)
    limits_min = min(limits_from.min, limits_to.min)
    limits_max = min(limits_from.max, limits_to.max)

    tap_transformer = PSY.get_component(TapTransformer, system, "Trans3")
    rate_limit = PSY.get_rate(tap_transformer)

    transformer = PSY.get_component(Transformer2W, system, "Trans4")
    rate_limit2w = PSY.get_rate(tap_transformer)

    for model in [DCPPowerModel, PTDFPowerModel]
        template = get_template_dispatch_with_network(
            NetworkModel(model; PTDF_matrix = PTDF(system)),
        )
        set_device_model!(
            template,
            DeviceModel(TwoTerminalHVDCLine, HVDCTwoTerminalUnbounded),
        )
        set_device_model!(template, DeviceModel(TapTransformer, StaticBranchBounds))
        set_device_model!(template, DeviceModel(Transformer2W, StaticBranchBounds))
        model_m = DecisionModel(template, system; optimizer = ipopt_optimizer)
        @test build!(model_m; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT

        @test check_variable_unbounded(
            model_m,
            FlowActivePowerVariable,
            TwoTerminalHVDCLine,
        )
        @test check_variable_bounded(model_m, FlowActivePowerVariable, TapTransformer)
        @test check_variable_bounded(model_m, FlowActivePowerVariable, TapTransformer)

        @test solve!(model_m) == RunStatus.SUCCESSFUL

        @test check_flow_variable_values(
            model_m,
            FlowActivePowerVariable,
            TwoTerminalHVDCLine,
            "DCLine3",
            limits_min,
            limits_max,
        )
        @test check_flow_variable_values(
            model_m,
            FlowActivePowerVariable,
            TapTransformer,
            "Trans3",
            -rate_limit,
            rate_limit,
        )
        @test check_flow_variable_values(
            model_m,
            FlowActivePowerVariable,
            Transformer2W,
            "Trans4",
            -rate_limit2w,
            rate_limit2w,
        )
    end
end

@testset "HVDCTwoTerminalLossless values check between network models" begin
    # Test to compare lossless models with lossless formulation
    sys_5 = build_system(PSITestSystems, "c_sys5_uc")

    line = get_component(Line, sys_5, "1")
    remove_component!(sys_5, line)

    hvdc = TwoTerminalHVDCLine(;
        name = get_name(line),
        available = true,
        active_power_flow = 0.0,
        # Force the flow in the opposite direction for testing purposes
        active_power_limits_from = (min = -0.5, max = -0.5),
        active_power_limits_to = (min = -3.0, max = 2.0),
        reactive_power_limits_from = (min = -1.0, max = 1.0),
        reactive_power_limits_to = (min = -1.0, max = 1.0),
        arc = get_arc(line),
        loss = (l0 = 0.00, l1 = 0.00),
    )

    add_component!(sys_5, hvdc)

    template_uc = ProblemTemplate(
        NetworkModel(PTDFPowerModel; PTDF_matrix = PTDF(sys_5)),
    )

    set_device_model!(template_uc, ThermalStandard, ThermalCompactUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, FixedOutput)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranch))
    set_device_model!(
        template_uc,
        DeviceModel(TwoTerminalHVDCLine, HVDCTwoTerminalLossless),
    )

    model = DecisionModel(
        template_uc,
        sys_5;
        name = "UC",
        optimizer = HiGHS_optimizer,
        system_to_file = false,
    )
    build!(model; output_dir = mktempdir())

    solve!(model)

    ptdf_vars = get_variable_values(ProblemResults(model))
    ptdf_values =
        ptdf_vars[PowerSimulations.VariableKey{FlowActivePowerVariable, TwoTerminalHVDCLine}(
            "",
        )]
    ptdf_objective = model.internal.container.optimizer_stats.objective_value

    set_network_model!(template_uc, NetworkModel(DCPPowerModel))

    model = DecisionModel(
        template_uc,
        sys_5;
        name = "UC",
        optimizer = HiGHS_optimizer,
        system_to_file = false,
    )

    solve!(model; output_dir = mktempdir())
    dcp_vars = get_variable_values(ProblemResults(model))
    dcp_values =
        dcp_vars[PowerSimulations.VariableKey{FlowActivePowerVariable, TwoTerminalHVDCLine}(
            "",
        )]
    dcp_objective = model.internal.container.optimizer_stats.objective_value

    @test isapprox(dcp_objective, ptdf_objective; atol = 0.1)
    # Resulting solution is in the 4e5 order of magnitude
    @test all(isapprox.(ptdf_values[!, "1"], dcp_values[!, "1"]; atol = 10))
end

@testset "HVDCDispatch Model Tests" begin
    # Test to compare lossless models with lossless formulation
    sys_5 = build_system(PSITestSystems, "c_sys5_uc")

    line = get_component(Line, sys_5, "1")
    remove_component!(sys_5, line)

    hvdc = TwoTerminalHVDCLine(;
        name = get_name(line),
        available = true,
        active_power_flow = 0.0,
        # Force the flow in the opposite direction for testing purposes
        active_power_limits_from = (min = -2.0, max = -2.0),
        active_power_limits_to = (min = -3.0, max = 2.0),
        reactive_power_limits_from = (min = -1.0, max = 1.0),
        reactive_power_limits_to = (min = -1.0, max = 1.0),
        arc = get_arc(line),
        loss = (l0 = 0.00, l1 = 0.00),
    )

    add_component!(sys_5, hvdc)
    for net_model in [DCPPowerModel, PTDFPowerModel]
        @testset "$net_model" begin
            PSY.set_loss!(hvdc, (l0 = 0.0, l1 = 0.0))
            template_uc = ProblemTemplate(
                NetworkModel(net_model; PTDF_matrix = PTDF(sys_5), use_slacks = true),
            )

            set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
            set_device_model!(template_uc, RenewableDispatch, FixedOutput)
            set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
            set_device_model!(template_uc, DeviceModel(Line, StaticBranchUnbounded))
            set_device_model!(
                template_uc,
                DeviceModel(TwoTerminalHVDCLine, HVDCTwoTerminalLossless),
            )

            model_ref = DecisionModel(
                template_uc,
                sys_5;
                name = "UC",
                optimizer = HiGHS_optimizer,
                system_to_file = false,
            )

            solve!(model_ref; output_dir = mktempdir())
            ref_vars = get_variable_values(ProblemResults(model_ref))
            ref_values =
                ref_vars[PowerSimulations.VariableKey{FlowActivePowerVariable, Line}("")]
            hvdc_ref_values = ref_vars[PowerSimulations.VariableKey{
                FlowActivePowerVariable,
                TwoTerminalHVDCLine,
            }(
                "",
            )]
            ref_objective = model_ref.internal.container.optimizer_stats.objective_value
            ref_total_gen = sum(
                sum.(
                    eachrow(
                        ref_vars[PowerSimulations.VariableKey{
                            ActivePowerVariable,
                            ThermalStandard,
                        }(
                            "",
                        )],
                    ),
                ),
            )
            set_device_model!(
                template_uc,
                DeviceModel(TwoTerminalHVDCLine, HVDCTwoTerminalDispatch),
            )

            model = DecisionModel(
                template_uc,
                sys_5;
                name = "UC",
                optimizer = HiGHS_optimizer,
                system_to_file = false,
            )

            solve!(model; output_dir = mktempdir())
            no_loss_vars = get_variable_values(ProblemResults(model))
            no_loss_values =
                no_loss_vars[PowerSimulations.VariableKey{FlowActivePowerVariable, Line}(
                    "",
                )]
            hvdc_ft_no_loss_values = no_loss_vars[PowerSimulations.VariableKey{
                FlowActivePowerFromToVariable,
                TwoTerminalHVDCLine,
            }(
                "",
            )]
            hvdc_tf_no_loss_values = no_loss_vars[PowerSimulations.VariableKey{
                FlowActivePowerToFromVariable,
                TwoTerminalHVDCLine,
            }(
                "",
            )]
            no_loss_objective = model.internal.container.optimizer_stats.objective_value
            no_loss_total_gen = sum(
                sum.(
                    eachrow(
                        no_loss_vars[PowerSimulations.VariableKey{
                            ActivePowerVariable,
                            ThermalStandard,
                        }(
                            "",
                        )],
                    ),
                ),
            )

            @test isapprox(no_loss_objective, ref_objective; atol = 0.1)

            for col in names(ref_values)
                @test all(isapprox.(ref_values[!, col], no_loss_values[!, col]; atol = 0.1))
            end

            @test all(
                isapprox.(
                    hvdc_ft_no_loss_values[!, "1"],
                    hvdc_tf_no_loss_values[!, "1"];
                    atol = 1e-3,
                ),
            )

            @test isapprox(no_loss_total_gen, ref_total_gen; atol = 0.1)

            PSY.set_loss!(hvdc, (l0 = 0.1, l1 = 0.005))

            model_wl = DecisionModel(
                template_uc,
                sys_5;
                name = "UC",
                optimizer = HiGHS_optimizer,
                system_to_file = false,
            )

            solve!(model_wl; output_dir = mktempdir())
            dispatch_vars = get_variable_values(ProblemResults(model_wl))
            dispatch_values_ft = dispatch_vars[PowerSimulations.VariableKey{
                FlowActivePowerFromToVariable,
                TwoTerminalHVDCLine,
            }(
                "",
            )]
            dispatch_values_tf = dispatch_vars[PowerSimulations.VariableKey{
                FlowActivePowerToFromVariable,
                TwoTerminalHVDCLine,
            }(
                "",
            )]
            wl_total_gen = sum(
                sum.(
                    eachrow(
                        dispatch_vars[PowerSimulations.VariableKey{
                            ActivePowerVariable,
                            ThermalStandard,
                        }(
                            "",
                        )],
                    ),
                ),
            )
            dispatch_objective = model_wl.internal.container.optimizer_stats.objective_value

            # Note: for this test data the system does better by allowing more losses so
            # the total cost is lower.
            @test wl_total_gen > no_loss_total_gen

            for col in names(dispatch_values_tf)
                @test all(dispatch_values_tf[!, col] .<= dispatch_values_ft[!, col])
            end
        end
    end
end

@testset "DC Power Flow Models for TwoTerminalHVDCLine  Dispatch and TapTransformer & Transformer2W Unbounded" begin
    ratelimit_constraint_keys = [
        PSI.ConstraintKey(RateLimitConstraint, Transformer2W, "ub"),
        PSI.ConstraintKey(RateLimitConstraint, Line, "ub"),
        PSI.ConstraintKey(RateLimitConstraint, Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, TapTransformer, "ub"),
        PSI.ConstraintKey(RateLimitConstraint, Transformer2W, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, TapTransformer, "lb"),
        PSI.ConstraintKey(FlowRateConstraint, TwoTerminalHVDCLine, "ub"),
        PSI.ConstraintKey(FlowRateConstraint, TwoTerminalHVDCLine, "lb"),
    ]

    system = PSB.build_system(PSITestSystems, "c_sys14_dc")

    hvdc_line = PSY.get_component(TwoTerminalHVDCLine, system, "DCLine3")
    limits_from = PSY.get_active_power_limits_from(hvdc_line)
    limits_to = PSY.get_active_power_limits_to(hvdc_line)
    limits_min = min(limits_from.min, limits_to.min)
    limits_max = min(limits_from.max, limits_to.max)

    tap_transformer = PSY.get_component(TapTransformer, system, "Trans3")
    rate_limit = PSY.get_rate(tap_transformer)

    transformer = PSY.get_component(Transformer2W, system, "Trans4")
    rate_limit2w = PSY.get_rate(tap_transformer)

    template = get_template_dispatch_with_network(
        NetworkModel(PTDFPowerModel; PTDF_matrix = PTDF(system)),
    )
    set_device_model!(template, DeviceModel(TwoTerminalHVDCLine, HVDCTwoTerminalLossless))
    model_m = DecisionModel(template, system; optimizer = HiGHS_optimizer)
    @test build!(model_m; output_dir = mktempdir(; cleanup = true)) == PSI.BuildStatus.BUILT

    @test !check_variable_bounded(model_m, FlowActivePowerVariable, TapTransformer)
    @test !check_variable_bounded(model_m, FlowActivePowerVariable, Transformer2W)
    @test check_variable_unbounded(model_m, FlowActivePowerVariable, Line)

    psi_constraint_test(model_m, ratelimit_constraint_keys)

    @test solve!(model_m) == RunStatus.SUCCESSFUL

    @test check_flow_variable_values(
        model_m,
        FlowActivePowerVariable,
        TwoTerminalHVDCLine,
        "DCLine3",
        limits_max,
    )
    @test check_flow_variable_values(
        model_m,
        FlowActivePowerVariable,
        TapTransformer,
        "Trans3",
        rate_limit,
    )
    @test check_flow_variable_values(
        model_m,
        FlowActivePowerVariable,
        Transformer2W,
        "Trans4",
        rate_limit2w,
    )
end

@testset "DC Power Flow Models for PhaseShiftingTransformer and Line" begin
    system = build_system(PSITestSystems, "c_sys5_uc")

    line = get_component(Line, system, "1")
    remove_component!(system, line)

    ps = PhaseShiftingTransformer(;
        name = get_name(line),
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        r = get_r(line),
        x = get_r(line),
        primary_shunt = 0.0,
        tap = 1.0,
        α = 0.0,
        rate = get_rate(line),
        arc = get_arc(line),
    )

    add_component!(system, ps)

    template = get_template_dispatch_with_network(
        NetworkModel(PTDFPowerModel; PTDF_matrix = PTDF(system)),
    )
    set_device_model!(template, DeviceModel(PhaseShiftingTransformer, PhaseAngleControl))
    model_m = DecisionModel(template, system; optimizer = HiGHS_optimizer)
    @test build!(model_m; output_dir = mktempdir(; cleanup = true)) == PSI.BuildStatus.BUILT

    @test check_variable_unbounded(model_m, FlowActivePowerVariable, Line)
    @test check_variable_unbounded(
        model_m,
        FlowActivePowerVariable,
        PhaseShiftingTransformer,
    )

    @test solve!(model_m) == RunStatus.SUCCESSFUL

    @test check_flow_variable_values(
        model_m,
        FlowActivePowerVariable,
        PhaseShiftingTransformer,
        "1",
        get_rate(ps),
    )

    @test check_flow_variable_values(
        model_m,
        PhaseShifterAngle,
        PhaseShiftingTransformer,
        "1",
        -π / 2,
        π / 2,
    )
end

@testset "AC Power Flow Models for TwoTerminalHVDCLine  Flow Constraints and TapTransformer & Transformer2W Unbounded" begin
    ratelimit_constraint_keys = [
        PSI.ConstraintKey(RateLimitConstraintFromTo, Transformer2W),
        PSI.ConstraintKey(RateLimitConstraintToFrom, Transformer2W),
        PSI.ConstraintKey(RateLimitConstraintFromTo, TapTransformer),
        PSI.ConstraintKey(RateLimitConstraintToFrom, TapTransformer),
        PSI.ConstraintKey(FlowRateConstraint, TwoTerminalHVDCLine, "ub"),
        PSI.ConstraintKey(FlowRateConstraint, TwoTerminalHVDCLine, "lb"),
    ]

    system = PSB.build_system(PSITestSystems, "c_sys14_dc")

    hvdc_line = PSY.get_component(TwoTerminalHVDCLine, system, "DCLine3")
    limits_from = PSY.get_active_power_limits_from(hvdc_line)
    limits_to = PSY.get_active_power_limits_to(hvdc_line)
    limits_min = min(limits_from.min, limits_to.min)
    limits_max = min(limits_from.max, limits_to.max)

    tap_transformer = PSY.get_component(TapTransformer, system, "Trans3")
    rate_limit = PSY.get_rate(tap_transformer)

    transformer = PSY.get_component(Transformer2W, system, "Trans4")
    rate_limit2w = PSY.get_rate(tap_transformer)

    template = get_template_dispatch_with_network(ACPPowerModel)
    set_device_model!(template, DeviceModel(TwoTerminalHVDCLine, HVDCTwoTerminalLossless))
    model_m = DecisionModel(template, system; optimizer = ipopt_optimizer)
    @test build!(model_m; output_dir = mktempdir(; cleanup = true)) == PSI.BuildStatus.BUILT

    @test check_variable_bounded(model_m, FlowActivePowerFromToVariable, TapTransformer)
    @test check_variable_unbounded(model_m, FlowReactivePowerFromToVariable, TapTransformer)
    @test check_variable_bounded(model_m, FlowActivePowerToFromVariable, Transformer2W)
    @test check_variable_unbounded(model_m, FlowReactivePowerToFromVariable, Transformer2W)

    psi_constraint_test(model_m, ratelimit_constraint_keys)

    @test solve!(model_m) == RunStatus.SUCCESSFUL

    @test check_flow_variable_values(
        model_m,
        FlowActivePowerVariable,
        FlowReactivePowerToFromVariable,
        TwoTerminalHVDCLine,
        "DCLine3",
        limits_max,
    )
    @test check_flow_variable_values(
        model_m,
        FlowActivePowerFromToVariable,
        FlowReactivePowerFromToVariable,
        TapTransformer,
        "Trans3",
        rate_limit,
    )
    @test check_flow_variable_values(
        model_m,
        FlowActivePowerToFromVariable,
        FlowReactivePowerToFromVariable,
        Transformer2W,
        "Trans4",
        rate_limit2w,
    )
end
