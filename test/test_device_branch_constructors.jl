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
        # TODO: use accessors to remove the use of Symbols Directly
        monitored_line_variable = PSI.get_variable(
            op_problem_m.internal.optimization_container,
            :Fp__MonitoredLine,
        )
        static_line_variable =
            PSI.get_variable(op_problem_m.internal.optimization_container, :Fp__Line)

        for b in monitored_line_variable
            @test JuMP.has_lower_bound(b)
            @test JuMP.has_upper_bound(b)
        end
        for b in static_line_variable
            @test !JuMP.has_lower_bound(b)
            @test !JuMP.has_upper_bound(b)
        end
        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
        flow = JuMP.value(monitored_line_variable["1", 1])
        @test isapprox(flow, limits.from_to, atol = 1e-2)
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
        # TODO: use accessors to remove the use of Symbols Directly
        monitored_line_variable = PSI.get_variable(
            op_problem_m.internal.optimization_container,
            :Fp__MonitoredLine,
        )
        static_line_variable =
            PSI.get_variable(op_problem_m.internal.optimization_container, :Fp__Line)

        for b in monitored_line_variable
            @test !JuMP.has_lower_bound(b)
            @test !JuMP.has_upper_bound(b)
        end
        for b in static_line_variable
            # Broken
            #@test JuMP.has_lower_bound(b)
            #@test JuMP.has_upper_bound(b)
        end
        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
        flow = JuMP.value(static_line_variable["2", 1])
        @test flow <= (1.5 + 1e-2)
    end
end

@testset "AC Power Flow Monitored Line Flow Constraints" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    line = PSY.get_component(MonitoredLine, system, "1")
    limits = PSY.get_flow_limits(line)
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

    for b in pFT_line_variable
        @test JuMP.has_lower_bound(b)
        @test JuMP.has_upper_bound(b)
    end

    for b in qFT_line_variable
        @test !JuMP.has_lower_bound(b)
        @test !JuMP.has_upper_bound(b)
    end

    @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
    fq = JuMP.value(qFT_line_variable["1", 1])
    fp = JuMP.value(pFT_line_variable["1", 1])
    flow = sqrt((fp[1])^2 + (fq[1])^2)
    @test isapprox(flow, limits.from_to, atol = 1e-2)
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
            for v in hvdc_line_variable
                @test JuMP.has_lower_bound(v)
                @test JuMP.has_upper_bound(v)
            end

            for v in tap_transformer_variable
                @test !JuMP.has_lower_bound(v)
                @test !JuMP.has_upper_bound(v)
            end

            for v in transformer_variable
                @test !JuMP.has_lower_bound(v)
                @test !JuMP.has_upper_bound(v)
            end

        end

        psi_constraint_test(op_problem_m, ratelimit_constraint_names)

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

        flow = JuMP.value(hvdc_line_variable["DCLine3", 1])
        @test flow <= (limits_max + 1e-2) && flow >= (limits_min + 1e-2)

        flow_tap = JuMP.value(tap_transformer_variable["Trans3", 1])
        @test flow_tap <= (rate_limit + 1e-2) && flow_tap >= -(rate_limit + 1e-2)

        flow_trans = JuMP.value(transformer_variable["Trans4", 1])
        @test flow_trans <= (rate_limit2w + 1e-2) && flow_trans >= -(rate_limit2w + 1e-2)
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
            for v in hvdc_line_variable
                # TODO: Remove variable bounds in HVDCUnbounded
                # @test !JuMP.has_lower_bound(v)
                # @test !JuMP.has_upper_bound(v)
            end

            for v in tap_transformer_variable
                @test JuMP.has_lower_bound(v)
                @test JuMP.has_upper_bound(v)
            end

            for v in transformer_variable
                @test JuMP.has_lower_bound(v)
                @test JuMP.has_upper_bound(v)
            end
        end

        @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

        flow = JuMP.value(hvdc_line_variable["DCLine3", 1])
        @test flow <= (limits_max + 1e-2) && flow >= (limits_min + 1e-2)

        flow_tap = JuMP.value(tap_transformer_variable["Trans3", 1])
        @test flow_tap <= (rate_limit + 1e-2) && flow_tap >= -(rate_limit + 1e-2)

        flow_trans = JuMP.value(transformer_variable["Trans4", 1])
        @test flow_trans <= (rate_limit2w + 1e-2) && flow_trans >= -(rate_limit2w + 1e-2)
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

    for v in qFT_line_variable
        @test JuMP.has_lower_bound(v)
        @test JuMP.has_upper_bound(v)
    end

    for v in pFT_line_variable
        @test JuMP.has_lower_bound(v)
        @test JuMP.has_upper_bound(v)
    end

    for v in pFT_tap_variable
        @test JuMP.has_lower_bound(v)
        @test JuMP.has_upper_bound(v)
    end

    for v in qFT_tap_variable
        @test !JuMP.has_lower_bound(v)
        @test !JuMP.has_upper_bound(v)
    end

    for v in pFT_transformer_variable
        @test JuMP.has_lower_bound(v)
        @test JuMP.has_upper_bound(v)
    end

    for v in qFT_transformer_variable
        @test !JuMP.has_lower_bound(v)
        @test !JuMP.has_upper_bound(v)
    end

    psi_constraint_test(op_problem_m, ratelimit_constraint_names)

    @test solve!(op_problem_m) == RunStatus.SUCCESSFUL

    fq = JuMP.value(qFT_line_variable["DCLine3", 1])
    fp = JuMP.value(pFT_line_variable["DCLine3", 1])
    flow = sqrt((fp[1])^2 + (fq[1])^2)
    @test flow <= (limits_max + 1e-2) && flow >= (limits_min + 1e-2)

    fq = JuMP.value(qFT_tap_variable["Trans3", 1])
    fp = JuMP.value(pFT_tap_variable["Trans3", 1])
    flow = sqrt((fp[1])^2 + (fq[1])^2)
    @test flow <= (rate_limit+1e-2)

    fq = JuMP.value(qFT_transformer_variable["Trans4", 1])
    fp = JuMP.value(pFT_transformer_variable["Trans4", 1])
    flow = sqrt((fp[1])^2 + (fq[1])^2)
    @test flow <= (rate_limit2w+1e-2)
end
