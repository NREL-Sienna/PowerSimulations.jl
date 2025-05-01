test_path = mktempdir()

const TIME1 = DateTime("2024-01-01T00:00:00")
const TIME2 = TIME1 + Hour(1)
const TIME3 = TIME1 + Day(1)

@testset "Test Thermal Generation Cost Functions " begin
    test_cases = [
        ("linear_cost_test", 4664.88, ThermalBasicUnitCommitment),
        ("linear_fuel_test", 4664.88, ThermalBasicUnitCommitment),
        ("quadratic_cost_test", 3301.81, ThermalDispatchNoMin),
        ("quadratic_fuel_test", 3331.12, ThermalDispatchNoMin),
        ("pwl_io_cost_test", 3421.64, ThermalBasicUnitCommitment),
        ("pwl_io_fuel_test", 3421.64, ThermalBasicUnitCommitment),
        ("pwl_incremental_cost_test", 3424.43, ThermalBasicUnitCommitment),
        ("pwl_incremental_fuel_test", 3424.43, ThermalBasicUnitCommitment),
        ("non_convex_io_pwl_cost_test", 3047.14, ThermalBasicUnitCommitment),
    ]
    for (i, cost_reference, thermal_formulation) in test_cases
        @testset "$i" begin
            sys = build_system(PSITestSystems, "c_$(i)")
            template = ProblemTemplate(NetworkModel(CopperPlatePowerModel))
            set_device_model!(template, ThermalStandard, thermal_formulation)
            set_device_model!(template, PowerLoad, StaticPowerLoad)
            model = DecisionModel(
                template,
                sys;
                name = "UC_$(i)",
                optimizer = HiGHS_optimizer,
                system_to_file = false,
                optimizer_solve_log_print = true,
            )
            @test build!(model; output_dir = test_path) == PSI.ModelBuildStatus.BUILT
            @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
            results = OptimizationProblemResults(model)
            expr = read_expression(results, "ProductionCostExpression__ThermalStandard")
            var_unit_cost = sum(expr[!, "Test Unit"])
            @test isapprox(var_unit_cost, cost_reference; atol = 1)
            @test expr[!, "Test Unit"][end] == 0.0
        end
    end
end

#TODO: This test
#=
@testset "Test Thermal Generation Cost Functions Fuel Cost time series" begin
    test_cases = [
        "linear_fuel_test_ts",
        "quadratic_fuel_test_ts",
        "pwl_io_fuel_test_ts",
        "pwl_incremental_fuel_test_ts",
        "market_bid_cost",
    ]
    for i in test_cases
        @testset "$i" begin
            sys = build_system(PSITestSystems, "c_$(i)")
            template = ProblemTemplate(NetworkModel(CopperPlatePowerModel))
            set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
            #=
            model = DecisionModel(
                template,
                sys;
                name = "UC_$(i)",
                optimizer = HiGHS_optimizer,
                system_to_file = false,
            )
            @test build!(model; output_dir = test_path) == PSI.ModelBuildStatus.BUILT
            @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
            =#
        end
    end
end
=#

#TODO: timeseries market_bid_cost
@testset "Test Thermal Generation MarketBidCost models" begin
    test_cases = [
        ("Base case", "fixed_market_bid_cost", 20532.76, 30.0, 30.0),
        ("Greater initial input, no load", "fixed_market_bid_cost", 20532.76, 31.0, 31.0),
        ("Greater initial input only", "fixed_market_bid_cost", 20532.76, 30.0, 31.0),
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

################################### Unit Commitment tests ##################################
@testset "Thermal UC With DC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalStandard),
        PSI.VariableKey(StartVariable, PSY.ThermalStandard),
        PSI.VariableKey(StopVariable, PSY.ThermalStandard),
    ]

    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "dn"),
    ]

    aux_variables_keys = [
        PSI.AuxVarKey(PSI.TimeDurationOff, ThermalStandard),
        PSI.AuxVarKey(PSI.TimeDurationOn, ThermalStandard),
    ]
    device_model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 480, 120, 120, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
    psi_aux_variable_test(model, aux_variables_keys)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal UC With AC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalStandard),
        PSI.VariableKey(StartVariable, PSY.ThermalStandard),
        PSI.VariableKey(StopVariable, PSY.ThermalStandard),
    ]
    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "dn"),
    ]

    aux_variables_keys = [
        PSI.AuxVarKey(PSI.TimeDurationOff, ThermalStandard),
        PSI.AuxVarKey(PSI.TimeDurationOn, ThermalStandard),
    ]

    device_model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 600, 240, 120, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
    psi_aux_variable_test(model, aux_variables_keys)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal MultiStart UC With DC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StartVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StopVariable, PSY.ThermalMultiStart),
    ]
    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "dn"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalMultiStart, "dn"),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 384, 0, 240, 48, 144, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart UC With AC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StartVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StopVariable, PSY.ThermalMultiStart),
    ]
    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "dn"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalMultiStart, "dn"),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 432, 0, 288, 96, 144, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
end

################################### Basic Unit Commitment tests ############################
@testset "Thermal Basic UC With DC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalStandard),
        PSI.VariableKey(StartVariable, PSY.ThermalStandard),
        PSI.VariableKey(StopVariable, PSY.ThermalStandard),
    ]
    device_model = DeviceModel(ThermalStandard, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal Basic UC With AC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalStandard),
        PSI.VariableKey(StartVariable, PSY.ThermalStandard),
        PSI.VariableKey(StopVariable, PSY.ThermalStandard),
    ]
    device_model = DeviceModel(ThermalStandard, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal MultiStart Basic UC With DC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StartVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StopVariable, PSY.ThermalMultiStart),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 384, 0, 96, 48, 144, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart Basic UC With AC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StartVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StopVariable, PSY.ThermalMultiStart),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 432, 0, 144, 96, 144, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
end

################################### Basic Dispatch tests ###################################
@testset "ThermalStandard with ThermalBasicDispatch With DC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 120, 120, 0, false)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 120, 120, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "ThermalStandard  with ThermalBasicDispatch With AC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")

    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 240, 240, 0, false)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 240, 240, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

# This Formulation is currently broken
@testset "ThermalMultiStart with ThermalBasicDispatch With DC - PF" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 48, 48, 96, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "ThermalMultiStart with ThermalBasicDispatch With AC - PF" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 288, 0, 96, 96, 96, false)
    psi_checkobjfun_test(model, GAEVF)
end

################################### No Minimum Dispatch tests ##############################
@testset "Thermal Dispatch NoMin With DC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 120, 120, 0, false)
    key = PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, ThermalStandard, "lb")
    moi_lbvalue_test(model, key, 0.0)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")

    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 120, 120, 0, false)
    key = PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, ThermalStandard, "lb")
    moi_lbvalue_test(model, key, 0.0)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal Dispatch NoMin With AC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 240, 240, 0, false)
    key = PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, ThermalStandard, "lb")
    moi_lbvalue_test(model, key, 0.0)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")

    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 240, 240, 0, false)
    key = PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, ThermalStandard, "lb")
    moi_lbvalue_test(model, key, 0.0)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal Dispatch NoMin With DC - PF" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_throws IS.ConflictingInputsError mock_construct_device!(model, device_model)
end

@testset "ThermalMultiStart Dispatch NoMin With AC - PF" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5;)
    @test_throws IS.ConflictingInputsError mock_construct_device!(model, device_model)
end

@testset "Operation Model ThermalDispatchNoMin - and PWL Non Convex" begin
    c_sys5_pwl_ed_nonconvex = PSB.build_system(PSITestSystems, "c_sys5_pwl_ed_nonconvex")
    template = get_thermal_dispatch_template_network()
    set_device_model!(template, DeviceModel(ThermalStandard, ThermalDispatchNoMin))
    model = DecisionModel(
        MockOperationProblem,
        CopperPlatePowerModel,
        c_sys5_pwl_ed_nonconvex;
        export_pwl_vars = true,
        initialize_model = false,
    )
    @test_throws IS.InvalidValue mock_construct_device!(
        model,
        DeviceModel(ThermalStandard, ThermalDispatchNoMin),
    )
end

################################## Ramp Limited Testing ##################################
@testset "ThermalStandard with ThermalStandardDispatch With DC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
    ]
    device_model = DeviceModel(ThermalStandard, ThermalStandardDispatch)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 168, 168, 0, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 120, 120, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "ThermalStandard with ThermalStandardDispatch With AC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
    ]
    device_model = DeviceModel(ThermalStandard, ThermalStandardDispatch)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 288, 288, 0, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 240, 240, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "ThermalMultiStart with ThermalStandardDispatch With DC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "dn"),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalStandardDispatch)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 96, 96, 96, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "ThermalMultiStart with ThermalStandardDispatch With AC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "dn"),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalStandardDispatch)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 288, 0, 144, 144, 96, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

################################### ThermalMultiStart Testing ##############################

@testset "Thermal MultiStart with MultiStart UC and DC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(ActiveRangeICConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(StartTypeConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(
            StartupTimeLimitTemperatureConstraint,
            PSY.ThermalMultiStart,
            "warm",
        ),
        PSI.ConstraintKey(
            StartupTimeLimitTemperatureConstraint,
            PSY.ThermalMultiStart,
            "hot",
        ),
        PSI.ConstraintKey(
            StartupInitialConditionConstraint,
            PSY.ThermalMultiStart,
            "lb",
        ),
        PSI.ConstraintKey(
            StartupInitialConditionConstraint,
            PSY.ThermalMultiStart,
            "ub",
        ),
    ]
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    no_less_than = Dict(true => 334, false => 282)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 528, 0, no_less_than[false], 108, 192, true)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with MultiStart UC and AC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(ActiveRangeICConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(StartTypeConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(
            StartupTimeLimitTemperatureConstraint,
            PSY.ThermalMultiStart,
            "warm",
        ),
        PSI.ConstraintKey(
            StartupTimeLimitTemperatureConstraint,
            PSY.ThermalMultiStart,
            "hot",
        ),
        PSI.ConstraintKey(
            StartupInitialConditionConstraint,
            PSY.ThermalMultiStart,
            "lb",
        ),
        PSI.ConstraintKey(
            StartupInitialConditionConstraint,
            PSY.ThermalMultiStart,
            "ub",
        ),
    ]
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    no_less_than = Dict(true => 382, false => 330)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 576, 0, no_less_than[false], 156, 192, true)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

################################ Thermal Compact UC Testing ################################
@testset "Thermal Standard with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 480, 120, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 384, 0, 240, 48, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal Standard with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 600, 240, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 432, 0, 288, 96, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

################################ Thermal Basic Compact UC Testing ################################
@testset "Thermal Standard with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 240, 120, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 384, 0, 96, 48, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal Standard with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 360, 240, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 432, 0, 144, 96, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

############################ Thermal Compact Dispatch Testing ##############################
@testset "Thermal Standard with Compact Dispatch and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 245, 0, 144, 144, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact Dispatch and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 290, 0, 96, 96, 96, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal Standard with Compact Dispatch and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 365, 0, 264, 264, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact Dispatch and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 338, 0, 144, 144, 96, false)
    psi_checkobjfun_test(model, GAEVF)
end

############################# Model validation tests #######################################
@testset "Solving ED with CopperPlate for testing Ramping Constraints" begin
    ramp_test_sys = PSB.build_system(PSITestSystems, "c_ramp_test")
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, ThermalStandard, ThermalStandardDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    ED = DecisionModel(
        EconomicDispatchProblem,
        template,
        ramp_test_sys;
        optimizer = HiGHS_optimizer,
        initialize_model = false,
    )
    @test build!(ED; output_dir = mktempdir(; cleanup = true)) == PSI.ModelBuildStatus.BUILT
    moi_tests(ED, 10, 0, 15, 15, 5, false)
    psi_checksolve_test(ED, [MOI.OPTIMAL], 11191.00)
end

# Testing Duration Constraints
@testset "Solving UC with CopperPlate for testing Duration Constraints" begin
    template = get_thermal_standard_uc_template()
    UC = DecisionModel(
        UnitCommitmentProblem,
        template,
        PSB.build_system(PSITestSystems, "c_duration_test");
        optimizer = HiGHS_optimizer,
        initialize_model = false,
        store_variable_names = true,
    )
    build!(UC; output_dir = mktempdir(; cleanup = true))
    @test build!(UC; output_dir = mktempdir(; cleanup = true)) == PSI.ModelBuildStatus.BUILT
    moi_tests(UC, 56, 0, 56, 14, 21, true)
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8223.50)
end

#= Test disabled due to inconsistency between the models and the data
@testset "UC with MarketBid Cost in ThermalGenerators" begin
    sys = PSB.build_system(PSITestSystems, "c_market_bid_cost")
    template = get_thermal_standard_uc_template()
    set_device_model!(
        template,
        DeviceModel(ThermalMultiStart, ThermalMultiStartUnitCommitment),
    )
    UC = DecisionModel(
        UnitCommitmentProblem,
        template,
        sys;
        optimizer = HiGHS_optimizer,
        initialize_model = false,
    )
    @test build!(UC; output_dir = mktempdir(; cleanup = true)) == PSI.ModelBuildStatus.BUILT
    moi_tests(UC, 38, 0, 16, 8, 16, true)
end
=#

@testset "Solving UC Models with Linear Networks" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys5_dc = PSB.build_system(PSITestSystems, "c_sys5_dc")
    systems = [c_sys5, c_sys5_dc]
    networks = [DCPPowerModel, NFAPowerModel, PTDFPowerModel, CopperPlatePowerModel]
    commitment_models = [ThermalStandardUnitCommitment, ThermalCompactUnitCommitment]

    for net in networks, sys in systems, model in commitment_models
        template = get_thermal_dispatch_template_network(
            NetworkModel(net),
        )
        set_device_model!(template, ThermalStandard, model)
        UC = DecisionModel(template, sys; optimizer = HiGHS_optimizer)
        @test build!(UC; output_dir = mktempdir(; cleanup = true)) ==
              PSI.ModelBuildStatus.BUILT
        psi_checksolve_test(UC, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED], 340000, 100000)
    end
end

@testset "Test Feedforwards to ThermalStandard with ThermalStandardDispatch" begin
    device_model = DeviceModel(ThermalStandard, ThermalStandardDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalStandard,
        source = OnVariable,
        affected_values = [ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalStandard,
        source = ActivePowerVariable,
        affected_values = [ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 365, 0, 264, 144, 0, false)
end

@testset "Test Feedforwards to ThermalStandard with ThermalBasicDispatch" begin
    device_model = DeviceModel(ThermalStandard, ThermalBasicDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalStandard,
        source = OnVariable,
        affected_values = [ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalStandard,
        source = ActivePowerVariable,
        affected_values = [ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 360, 0, 240, 120, 0, false)
end

@testset "Test Feedforwards to ThermalStandard with ThermalCompactDispatch" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalStandard,
        source = OnVariable,
        affected_values = [PowerAboveMinimumVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalStandard,
        source = PSI.PowerAboveMinimumVariable,
        affected_values = [PSI.PowerAboveMinimumVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 365, 0, 264, 144, 0, false)
end

@testset "Test Feedforwards to ThermalMultiStart with ThermalStandardDispatch" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalStandardDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalMultiStart,
        source = OnVariable,
        affected_values = [ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalMultiStart,
        source = ActivePowerVariable,
        affected_values = [ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 338, 0, 144, 96, 96, false)
end

@testset "Test Feedforwards to ThermalMultiStart with ThermalBasicDispatch" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalMultiStart,
        source = OnVariable,
        affected_values = [ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalMultiStart,
        source = ActivePowerVariable,
        affected_values = [ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 336, 0, 96, 48, 96, false)
end

@testset "Test Feedforwards to ThermalMultiStart with ThermalCompactDispatch" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalMultiStart,
        source = OnVariable,
        affected_values = [PSI.PowerAboveMinimumVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalMultiStart,
        source = PSI.PowerAboveMinimumVariable,
        affected_values = [PSI.PowerAboveMinimumVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 338, 0, 144, 96, 96, false)
end

@testset "Test Must Run ThermalGen" begin
    sys_5 = build_system(PSITestSystems, "c_sys5_uc")
    template_uc =
        ProblemTemplate(NetworkModel(CopperPlatePowerModel))
    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    #set_device_model!(template_uc, RenewableDispatch, FixedOutput)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranchUnbounded))

    # Set Must Run the most expensive one: Sundance
    sundance = get_component(ThermalStandard, sys_5, "Sundance")
    set_must_run!(sundance, true)
    for rebuild in [true, false]
        model = DecisionModel(
            template_uc,
            sys_5;
            name = "UC",
            optimizer = HiGHS_optimizer,
            system_to_file = false,
            store_variable_names = true,
            rebuild_model = rebuild,
        )

        solve!(model; output_dir = mktempdir())
        ptdf_vars = get_variable_values(OptimizationProblemResults(model))
        power =
            ptdf_vars[PowerSimulations.VariableKey{ActivePowerVariable, ThermalStandard}(
                "",
            )]
        on = ptdf_vars[PowerSimulations.VariableKey{OnVariable, ThermalStandard}("")]
        start = ptdf_vars[PowerSimulations.VariableKey{StartVariable, ThermalStandard}("")]
        stop = ptdf_vars[PowerSimulations.VariableKey{StopVariable, ThermalStandard}("")]
        power_sundance = power[!, "Sundance"]
        @test all(power_sundance .>= 1.0)
        for v in [on, start, stop]
            @test "Sundance" ∉ names(v)
        end
    end
end

@testset "Thermal with max_active_power time series" begin
    device_model = DeviceModel(
        ThermalStandard,
        ThermalStandardUnitCommitment;
        time_series_names = Dict(ActivePowerTimeSeriesParameter => "max_active_power"))
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")

    derate_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
    data_ts = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  23:00:00",
            "d/m/y  H:M:S",
        ),
    )
    for t in 1:2
        ini_time = data_ts[1] + Day(t - 1)
        derate_data[ini_time] =
            TimeArray(data_ts + Day(t - 1), fill!(Vector{Float64}(undef, 24), 0.8))
    end
    solitude = get_component(ThermalStandard, c_sys5, "Solitude")
    PSY.add_time_series!(
        c_sys5,
        solitude,
        PSY.Deterministic("max_active_power", derate_data),
    )

    model = DecisionModel(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5)

    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 504, 120, 120, true)
    key = PSI.ConstraintKey(
        ActivePowerVariableTimeSeriesLimitsConstraint,
        ThermalStandard,
        "ub",
    )
    constraint = PSI.get_constraint(PSI.get_optimization_container(model), key)
    ub_value = get_max_active_power(solitude) * 0.8
    for ix in eachindex(constraint)
        @test JuMP.normalized_rhs(constraint[ix]) == ub_value
    end
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal with fuel cost time series" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_re_fuel_cost")

    template = ProblemTemplate(
        NetworkModel(
            CopperPlatePowerModel;
            duals = [CopperPlateBalanceConstraint],
        ),
    )

    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)

    model = DecisionModel(
        template,
        sys;
        name = "UC",
        optimizer = HiGHS_optimizer,
        system_to_file = false,
        store_variable_names = true,
        optimizer_solve_log_print = false,
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

    build!(sim; console_level = Logging.Error, serialize = false)
    moi_tests(model, 432, 0, 192, 120, 72, false)
    execute!(sim; enable_progress_bar = true)

    sim_res = SimulationResults(sim)
    res_uc = get_decision_problem_results(sim_res, "UC")

    # Test time series <-> parameter correspondence
    fc_uc = read_parameter(res_uc, PSI.FuelCostParameter, PSY.ThermalStandard)
    for (step_dt, step_df) in pairs(fc_uc)
        for gen_name in names(DataFrames.select(step_df, Not(:DateTime)))
            fc_comp = get_fuel_cost(
                get_component(ThermalStandard, sys, gen_name);
                start_time = step_dt,
            )
            @test all(step_df[!, :DateTime] .== TimeSeries.timestamp(fc_comp))
            @test all(isapprox.(step_df[!, gen_name], TimeSeries.values(fc_comp)))
        end
    end

    # Test effect on decision
    th_uc = read_realized_variable(res_uc, "ActivePowerVariable__ThermalStandard")
    p_brighton = th_uc[!, "Brighton"]
    p_solitude = th_uc[!, "Solitude"]

    @test sum(p_brighton[1:24]) < 50.0 # Barely used when expensive
    @test sum(p_brighton[25:48]) > 5000.0 # Used a lot when cheap
    @test sum(p_solitude[1:24]) > 5000.0 # Used a lot when cheap
    @test sum(p_solitude[25:48]) < 50.0 # Barely used when expensive
end

@testset "Thermal with fuel cost time series with Quadratic and PWL" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_re_fuel_cost")

    template = ProblemTemplate(
        NetworkModel(
            CopperPlatePowerModel;
            duals = [CopperPlateBalanceConstraint],
        ),
    )

    solitude = get_component(ThermalStandard, sys, "Solitude")
    op_cost = get_operation_cost(solitude)
    ts = deepcopy(get_time_series(Deterministic, solitude, "fuel_cost"))
    remove_time_series!(sys, Deterministic, solitude, "fuel_cost")
    quad_curve = QuadraticCurve(0.05, 1.0, 0.0)
    new_th_cost = ThermalGenerationCost(;
        variable = FuelCurve(;
            value_curve = quad_curve,
            fuel_cost = 1.0,
        ),
        fixed = op_cost.fixed,
        start_up = op_cost.start_up,
        shut_down = op_cost.shut_down,
    )

    set_operation_cost!(solitude, new_th_cost)
    add_time_series!(
        sys,
        solitude,
        ts,
    )

    # There is no free MIQP solver, we need to use ThermalDisptchNoMin for testing
    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)

    model = DecisionModel(
        template,
        sys;
        name = "UC",
        optimizer = ipopt_optimizer,
        system_to_file = false,
        store_variable_names = true,
        optimizer_solve_log_print = false,
    )
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    solve!(model)
    moi_tests(model, 288, 0, 192, 120, 72, false)
    container = PSI.get_optimization_container(model)
    @test isa(
        PSI.get_invariant_terms(PSI.get_objective_expression(container)),
        JuMP.QuadExpr,
    )
end

"Set the no_load_cost and input_at_zero to `nothing` and the initial_input to the old no_load_cost. Not designed for time series"
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
) =
    no_load_to_initial_input!.(get_components(sel, sys))

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

function load_sys_incr()
    sys = Logging.with_logger(Logging.NullLogger()) do
        build_system(PSITestSystems, "c_fixed_market_bid_cost")  # note we are using the fixed one so we can add time series ourselves
    end
    no_load_to_initial_input!(sys)
    return sys
end

function load_sys_decr()
    sys = Logging.with_logger(Logging.NullLogger()) do
        build_system(PSITestSystems, "c_sys5_il")  # note we are using the fixed one so we can add time series ourselves
    end
    no_load_to_initial_input!(sys)
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
        vcat(values(read_variable(res_uc, var_name, gentype))...), unit_name .=> sum)[
        1,
        1,
    ]

function run_generic_mbc_sim(sys::System; multistart::Bool = false)
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

    # Test solving the model outside of a Simulation
    model_ = deepcopy(model)
    @test build!(model_; output_dir = test_path) == PSI.ModelBuildStatus.BUILT
    @test solve!(model_) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

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
    return model_, model, res_uc
end

"Run a simple simulation with the system and return information useful for testing time-varying startup and shutdown functionality"
function run_startup_shutdown_sim(sys::System; multistart::Bool = false)
    model_, model, res_uc = run_generic_mbc_sim(sys; multistart = multistart)

    # Test correctness of written shutdown cost parameters
    # TODO test startup too once we are able to write those
    gentype = multistart ? ThermalMultiStart : ThermalStandard
    genname = multistart ? "115_STEAM_1" : "Test Unit1"
    sh_uc = read_parameter(res_uc, PSI.ShutdownCostParameter, gentype)
    for (step_dt, step_df) in pairs(sh_uc)
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
            _read_one_value(res_uc, PSI.HotStartVariable, gentype, genname),
            _read_one_value(res_uc, PSI.WarmStartVariable, gentype, genname),
            _read_one_value(res_uc, PSI.ColdStartVariable, gentype, genname),
            _read_one_value(res_uc, PSI.StopVariable, gentype, genname),
        )
    else
        (
            _read_one_value(res_uc, PSI.StartVariable, gentype, genname),
            _read_one_value(res_uc, PSI.StopVariable, gentype, genname),
        )
    end
    return model_, model, res_uc, switches
end

"Run a simple simulation with the system and return information useful for testing time-varying startup and shutdown functionality"
function run_mbc_sim(sys::System; is_decremental::Bool = false)
    model_, model, res_uc = run_generic_mbc_sim(sys)

    ii_uc = read_parameter(res_uc, PSI.IncrementalCostAtMinParameter, ThermalStandard)
    for (step_dt, step_df) in pairs(ii_uc)
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
        _read_one_value(res_uc, PSI.OnVariable, gentype, genname)
    )
    return model_, model, res_uc, switches
end

"Read the relevant startup variables: no multistart case"
_read_start_vars(::Val{false}, res_uc::PSI.SimulationProblemResults) =
    read_variable(res_uc, PSI.StartVariable, ThermalStandard)

"Read the relevant startup variables: yes multistart case"
function _read_start_vars(::Val{true}, res_uc::PSI.SimulationProblemResults)
    hot_vars = read_variable(res_uc, PSI.HotStartVariable, ThermalMultiStart)
    warm_vars = read_variable(res_uc, PSI.WarmStartVariable, ThermalMultiStart)
    cold_vars = read_variable(res_uc, PSI.ColdStartVariable, ThermalMultiStart)

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
and stop variables in the `SimulationProblemResults` to determine the cost that should have
been incurred by time-varying `MarketBidCost` startup and shutdown costs. Must run
separately for multistart vs. not.
"""
function cost_due_to_time_varying_startup_shutdown(
    sys::System,
    res_uc::PSI.SimulationProblemResults;
    multistart = false,
)
    gentype = multistart ? ThermalMultiStart : ThermalStandard
    start_vars = _read_start_vars(Val(multistart), res_uc)
    stop_vars = read_variable(res_uc, PSI.StopVariable, gentype)
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
    res_uc::PSI.SimulationProblemResults;
    is_decremental = false,
)
    is_decremental && throw(IS.NotImplementedError("TODO implement for decremental"))
    gentype = ThermalStandard
    on_vars = read_variable(res_uc, PSI.OnVariable, gentype)
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

"Modifies `c_sys5_pglib` to facilitate the exercise of the multi-start capability in a test simulation"
function modify_sys_for_multistart!(sys::System, load_mult, therm_mult)
    for load in get_components(PowerLoad, sys)
        set_max_active_power!(load, get_max_active_power(load) * load_mult)
    end
    for therm in get_components(ThermalStandard, sys)
        op_cost = get_operation_cost(therm)
        prop = get_proportional_term(get_value_curve(get_variable(op_cost)))
        set_variable!(op_cost, CostCurve(LinearCurve(prop * therm_mult)))
    end
end

function create_multistart_sys(with_increments::Bool, load_mult, therm_mult)
    c_sys5_pglib = Logging.with_logger(Logging.NullLogger()) do
        PSB.build_system(PSITestSystems, "c_sys5_pglib")
    end
    no_load_to_initial_input!(c_sys5_pglib)
    modify_sys_for_multistart!(c_sys5_pglib, load_mult, therm_mult)
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
    ground_truth = total2 .- total1  # How much did the cost increase between simulation 1 and simulation 2 for each step

    obj1 = PSI.read_optimizer_stats(res_uc1)[!, "objective_value"]
    obj2 = PSI.read_optimizer_stats(res_uc2)[!, "objective_value"]
    obj_diff = obj2 .- obj1

    @test all(isapprox.(obj_diff, ground_truth; atol = 0.0001))
end

"""
The methodology here is: run a simulation where the startup and shutdown time series have
constant values through time, then run a nearly identical simulation where the values vary
very slightly through time, not enough to affect the decisions but enough to affect the
objective value, then compare the size of the objective value change to an expectation
computed manually.
"""
function run_startup_shutdown_obj_fun_test(sys1, sys2; multistart::Bool = false)
    model1_, model1, res_uc1, switches1 =
        run_startup_shutdown_sim(sys1; multistart = multistart)
    model2_, model2, res_uc2, switches2 =
        run_startup_shutdown_sim(sys2; multistart = multistart)

    ground_truth_1 =
        cost_due_to_time_varying_startup_shutdown(sys1, res_uc1; multistart = multistart)
    ground_truth_2 =
        cost_due_to_time_varying_startup_shutdown(sys2, res_uc2; multistart = multistart)

    _obj_fun_test_helper(ground_truth_1, ground_truth_2, res_uc1, res_uc2)
    return switches1, switches2
end

# Same methodology as run_startup_shutdown_obj_fun_test
function run_mbc_obj_fun_test(sys1, sys2; is_decremental::Bool = false)
    model1_, model1, res_uc1, switches1 = run_mbc_sim(sys1; is_decremental = is_decremental)
    model2_, model2, res_uc2, switches2 = run_mbc_sim(sys2; is_decremental = is_decremental)

    ground_truth_1 =
        cost_due_to_time_varying_mbc(sys1, res_uc1; is_decremental = is_decremental)
    ground_truth_2 =
        cost_due_to_time_varying_mbc(sys2, res_uc2; is_decremental = is_decremental)

    _obj_fun_test_helper(ground_truth_1, ground_truth_2, res_uc1, res_uc2)
    return switches1, switches2
end

@testset "MarketBidCost with time series startup and shutdown, ThermalStandard" begin
    # Test that constant time series has the same objective value as no time series
    sys0 = PSB.build_system(PSITestSystems, "c_fixed_market_bid_cost")
    no_load_to_initial_input!(sys0)
    cost = get_operation_cost(get_component(ThermalStandard, sys0, "Test Unit1"))
    set_start_up!(cost, (hot = 1.0, warm = 1.5, cold = 2.0))
    set_shut_down!(cost, 0.5)
    sys1 = PSB.build_system(PSITestSystems, "c_fixed_market_bid_cost")
    no_load_to_initial_input!(sys1)
    add_startup_shutdown_ts_a!(sys1, false)
    _, _, res_uc0 = run_generic_mbc_sim(sys0; multistart = false)
    _, _, res_uc1 = run_generic_mbc_sim(sys1; multistart = false)
    obj_val_0 = PSI.read_optimizer_stats(res_uc0)[!, "objective_value"]
    obj_val_1 = PSI.read_optimizer_stats(res_uc1)[!, "objective_value"]
    @test isapprox(obj_val_0, obj_val_1; atol = 0.0001)

    # Test that perturbing the time series perturbs the objective value as expected
    sys2 = PSB.build_system(PSITestSystems, "c_fixed_market_bid_cost")
    no_load_to_initial_input!(sys2)
    add_startup_shutdown_ts_a!(sys2, true)
    (switches1, switches2) = run_startup_shutdown_obj_fun_test(sys1, sys2)
    @test all(isapprox.(switches1, switches2))

    # Make sure our tests included sufficent startups and shutdowns
    @assert all(>=(1).(switches1))
end

@testset "MarketBidCost with time series startup and shutdown, ThermalMultiStart" begin
    # Scenario 1: hot and warm starts
    c_sys5_pglib1 = create_multistart_sys(false, 1.0, 7.5)
    c_sys5_pglib2 = create_multistart_sys(true, 1.0, 7.5)
    (switches1, switches2) =
        run_startup_shutdown_obj_fun_test(c_sys5_pglib1, c_sys5_pglib2; multistart = true)
    @test all(isapprox.(switches1, switches2))

    # Scenario 2: hot and cold starts
    c_sys5_pglib1 = create_multistart_sys(false, 1.05, 7.5)
    c_sys5_pglib2 = create_multistart_sys(true, 1.05, 7.5)
    (switches1_2, switches2_2) =
        run_startup_shutdown_obj_fun_test(c_sys5_pglib1, c_sys5_pglib2; multistart = true)
    @test all(isapprox.(switches1_2, switches2_2))

    # Make sure our tests included all types of startups and shutdowns
    @assert all(>=(1).(switches1 .+ switches1_2))
end

@testset "MarketBidCost incremental with time series min gen cost" begin
    baseline = build_sys_incr(false, false, false)
    plus_initial = build_sys_incr(true, false, false)

    switches1, switches2 = run_mbc_obj_fun_test(baseline, plus_initial)
    @test all(isapprox.(switches1, switches2))
    @assert all(>=(1).(switches1))

    # TODO test validate_initial_input_time_series warnings/errors
end

@testset "Thermal UC With Slack on Ramps" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalStandard),
        PSI.VariableKey(StartVariable, PSY.ThermalStandard),
        PSI.VariableKey(StopVariable, PSY.ThermalStandard),
    ]

    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "dn"),
    ]

    aux_variables_keys = [
        PSI.AuxVarKey(PSI.TimeDurationOff, ThermalStandard),
        PSI.AuxVarKey(PSI.TimeDurationOn, ThermalStandard),
    ]
    # Unit Commitment #
    device_model =
        DeviceModel(ThermalStandard, ThermalStandardUnitCommitment; use_slacks = true)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 720, 0, 480, 120, 120, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
    psi_aux_variable_test(model, aux_variables_keys)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, 720, 0, 240, 120, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GQEVF)

    # Dispatch #
    device_model =
        DeviceModel(ThermalStandard, ThermalStandardDispatch; use_slacks = true)
    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
    ]

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 360, 0, 168, 168, 0, false)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, 360, 0, 120, 120, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "ThermalDispatchNoMin with PWL Costs" begin
    sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")

    template = ProblemTemplate(NetworkModel(PTDFPowerModel))
    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template, Line, StaticBranchBounds)
    set_device_model!(template, TapTransformer, StaticBranchBounds)
    set_device_model!(template, Transformer2W, StaticBranchBounds)
    set_device_model!(template, PowerLoad, StaticPowerLoad)

    solver = HiGHS_optimizer
    problem = DecisionModel(template, sys;
        optimizer = solver,
        horizon = Hour(1),
        optimizer_solve_log_print = true,
        calculate_conflict = true,
        store_variable_names = true,
        detailed_optimizer_stats = false,
    )

    build!(problem; output_dir = mktempdir())

    solve!(problem)

    res = OptimizationProblemResults(problem)

    # Test that plant 101_STEAM_3 (using max power) have proper cost expression
    cost = read_expression(res, "ProductionCostExpression__ThermalStandard")
    p_th = read_variable(res, "ActivePowerVariable__ThermalStandard")
    steam3 = get_component(ThermalStandard, sys, "101_STEAM_3")
    val_curve = PSY.get_value_curve(PSY.get_variable(PSY.get_operation_cost(steam3)))
    io_curve = InputOutputCurve(val_curve)
    fuel_cost = PSY.get_fuel_cost(steam3)
    x_last = last(io_curve.function_data.points).x
    y_last = last(io_curve.function_data.points).y * fuel_cost
    p_steam3 = p_th[!, "101_STEAM_3"]
    cost_steam3 = cost[!, "101_STEAM_3"]
    @test isapprox(p_steam3[1], x_last) # max
    @test isapprox(cost_steam3[1], y_last) # last cost
end
