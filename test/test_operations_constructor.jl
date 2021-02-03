
devices = Dict{Symbol, DeviceModel}(
    :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
)
branches = Dict{Symbol, DeviceModel}(
    :L => DeviceModel(Line, StaticLine),
    :T => DeviceModel(Transformer2W, StaticTransformer),
    :TT => DeviceModel(TapTransformer, StaticTransformer),
)
services = Dict{Symbol, ServiceModel}()

@testset "Operation Model kwargs with CopperPlatePowerModel base" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")

    @test_throws ArgumentError OperationsProblem(
        TestOpProblem,
        template,
        c_sys5;
        bad_kwarg = 10,
    )
    op_problem = OperationsProblem(
        TestOpProblem,
        template,
        c_sys5;
        optimizer = GLPK_optimizer,
        use_parameters = true,
    )
    moi_tests(op_problem, true, 120, 0, 120, 120, 24, false)
    op_problem =
        OperationsProblem(TestOpProblem, template, c_sys14; optimizer = OSQP_optimizer)
    moi_tests(op_problem, false, 120, 0, 120, 120, 24, false)
    op_problem = OperationsProblem(
        TestOpProblem,
        template,
        c_sys5_re;
        use_forecast_data = false,
        optimizer = GLPK_optimizer,
    )
    moi_tests(op_problem, false, 5, 0, 5, 5, 1, false)
    op_problem = OperationsProblem(
        TestOpProblem,
        template,
        c_sys5_re;
        use_forecast_data = false,
        use_parameters = false,
        optimizer = GLPK_optimizer,
    )
    moi_tests(op_problem, false, 5, 0, 5, 5, 1, false)

    op_problem = OperationsProblem(
        TestOpProblem,
        template,
        c_sys5_re;
        optimizer = GLPK_optimizer,
        balance_slack_variables = true,
    )
    moi_tests(op_problem, false, 168, 0, 120, 120, 24, false)
end

@testset "Test optimization debugging functions" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem = OperationsProblem(
        TestOpProblem,
        template,
        c_sys5;
        optimizer = GLPK_optimizer,
        use_parameters = true,
    )
    MOIU.attach_optimizer(op_problem.optimization_container.JuMPmodel)
    constraint_indices = get_all_constraint_index(op_problem)
    for (key, index, moi_index) in constraint_indices
        val1 = get_con_index(op_problem, moi_index)
        val2 = op_problem.optimization_container.constraints[key].data[index]
        @test val1 == val2
    end
    @test isnothing(get_con_index(op_problem, length(constraint_indices) + 1))

    var_indices = get_all_var_index(op_problem)
    for (key, index, moi_index) in var_indices
        val1 = get_var_index(op_problem, moi_index)
        val2 = op_problem.optimization_container.variables[key].data[index]
        @test val1 == val2
    end
    @test isnothing(get_var_index(op_problem, length(var_indices) + 1))
end

@testset "Test passing custom JuMP model" begin
    my_model = JuMP.Model()
    my_model.ext[:PSI_Testing] = 1
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem = OperationsProblem(
        TestOpProblem,
        template,
        c_sys5,
        my_model;
        optimizer = GLPK_optimizer,
        use_parameters = true,
    )
    @test haskey(op_problem.optimization_container.JuMPmodel.ext, :PSI_Testing)
    @test (:params in keys(op_problem.optimization_container.JuMPmodel.ext)) == true
end

@testset "Operation Model Constructors with Parameters" begin
    networks = [
        CopperPlatePowerModel,
        StandardPTDFModel,
        DCPPowerModel,
        NFAPowerModel,
        ACPPowerModel,
        ACRPowerModel,
        ACTPowerModel,
        DCPLLPowerModel,
        LPACCPowerModel,
        SOCWRPowerModel,
        QCRMPowerModel,
        QCLSPowerModel,
    ]

    thermal_gens = [
        ThermalStandardUnitCommitment,
        ThermalDispatch,
        ThermalRampLimited,
        ThermalDispatchNoMin,
    ]

    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat")
    c_sys5_pwl_ed = PSB.build_system(PSITestSystems, "c_sys5_pwl_ed")
    systems = [c_sys5, c_sys5_re, c_sys5_bat, c_sys5_pwl_ed]
    for net in networks, thermal in thermal_gens, system in systems, p in [true, false]
        @testset "Operation Model $(net) - $(thermal)" begin
            devices = Dict{Symbol, DeviceModel}(
                :Generators => DeviceModel(ThermalStandard, thermal),
                :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
            )
            branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(Line, StaticLine))
            template = OperationsProblemTemplate(net, devices, branches, services)
            op_problem = OperationsProblem(
                TestOpProblem,
                template,
                system;
                use_parameters = p,
                PTDF = PTDF(system),
                export_pwl_vars = true,
            )
            @test :nodal_balance_active in
                  keys(op_problem.optimization_container.expressions)
            @test (:params in keys(op_problem.optimization_container.JuMPmodel.ext)) == p
        end
    end
end

@testset "Operation Model CopperPlatePowerModel - ThermalDispatchNoMin - c_sys5_pwl_ed_nonconvex" begin
    c_sys5_pwl_ed_nonconvex = PSB.build_system(PSITestSystems, "c_sys5_pwl_ed_nonconvex")
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatchNoMin),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    )
    branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(Line, StaticLine))
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    @test_throws IS.InvalidValue OperationsProblem(
        TestOpProblem,
        template,
        c_sys5_pwl_ed_nonconvex;
        use_parameters = true,
        PTDF = PTDF(c_sys5_pwl_ed_nonconvex),
        export_pwl_vars = true,
    )
end
@testset "Operations template constructors" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem_ed = PSI.EconomicDispatchProblem(c_sys5)
    op_problem_uc = PSI.UnitCommitmentProblem(c_sys5)
    moi_tests(op_problem_uc, false, 480, 0, 240, 120, 144, true)
    moi_tests(op_problem_ed, false, 120, 0, 168, 120, 24, false)
    ED = PSI.run_economic_dispatch(c_sys5; optimizer = fast_lp_optimizer)
    UC = PSI.run_unit_commitment(c_sys5; optimizer = fast_lp_optimizer)
    @test ED.optimizer_log[:primal_status] == MOI.FEASIBLE_POINT
    @test UC.optimizer_log[:primal_status] == MOI.FEASIBLE_POINT
end

@testset "Test print methods" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem = OperationsProblem(
        TestOpProblem,
        template,
        c_sys5;
        optimizer = GLPK_optimizer,
        use_parameters = true,
    )
    list = [template, op_problem, op_problem.optimization_container, services]
    _test_plain_print_methods(list)
    list = [services]
    _test_html_print_methods(list)
end
