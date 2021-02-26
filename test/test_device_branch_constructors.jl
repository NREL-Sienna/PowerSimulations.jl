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
    line = PSY.get_component(Line, system, "1")
    PSY.convert_component!(MonitoredLine, line, system)
    set_rate!(PSY.get_component(Line, system, "2"), 1.5)
    for model in [DCPPowerModel, StandardPTDFModel]
        template = get_thermal_dispatch_template_network(model)
        set_device_model!(template, DeviceModel(Line, StaticLine))
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

# Missing tests for transformers and DC lines
#=

@testset "AC Power Flow Monitored Line Flow Constraints" begin
    system = PSB.build_system(PSITestSystems, "c_sys5_ml")
    line = PSY.get_component(Line, system, "1")
    PSY.convert_component!(MonitoredLine, line, system)
    line = PSY.get_component(MonitoredLine, system, "1")
    limits = PSY.get_flow_limits(line)
    template = get_thermal_dispatch_template_network(ACPPowerModel)
    op_problem_m = OperationsProblem(
        template,
        system;
        optimizer = ipopt_optimizer,
    )
    @test build!(op_problem_m; output_dir = mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    @test solve!(op_problem_m) == RunStatus.SUCCESSFUL
    # TODO: use accessors to remove the use of Symbols Directly
    qFT_line_variable = PSI.get_variable(op_problem_m.internal.optimization_container, :FqFT__MonitoredLine)
    pFT_line_variable = PSI.get_variable(op_problem_m.internal.optimization_container, :FqFT__MonitoredLine)
    fq = JuMP.value(qFT_line_variable["1", 1])
    fp = JuMP.value(pFT_line_variable["1", 1])
    flow = sqrt((fp[1])^2 + (fq[1])^2)
    @test isapprox(flow, limits.from_to, atol = 1e-3)
end
=#
