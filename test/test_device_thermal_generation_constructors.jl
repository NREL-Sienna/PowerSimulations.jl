test_path = mktempdir()
@testset "ThermalGen data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    info_message = "The data doesn't include devices of type ThermalStandard, consider changing the device models"
    device_model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)
    c_sys5_re_only = PSB.build_system(PSITestSystems, "c_sys5_re_only")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_re_only)
    @test_logs (:info, info_message) match_mode = :any mock_construct_device!(
        model,
        device_model,
    )
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
    moi_tests(model, false, 480, 0, 480, 120, 120, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
    psi_aux_variable_test(model, aux_variables_keys)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 480, 0, 240, 120, 120, true)
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
    moi_tests(model, false, 600, 0, 600, 240, 120, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
    psi_aux_variable_test(model, aux_variables_keys)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 600, 0, 360, 240, 120, true)
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
    moi_tests(model, false, 384, 0, 240, 48, 144, true)
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
    moi_tests(model, false, 432, 0, 288, 96, 144, true)
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
    moi_tests(model, false, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 480, 0, 240, 120, 120, true)
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
    moi_tests(model, false, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 600, 0, 360, 240, 120, true)
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
    moi_tests(model, false, 384, 0, 96, 48, 144, true)
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
    moi_tests(model, false, 432, 0, 144, 96, 144, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
end

################################### Basic Dispatch tests ###################################
@testset "ThermalStandard with ThermalBasicDispatch With DC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 120, 0, 120, 120, 0, false)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 120, 0, 120, 120, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "ThermalStandard  with ThermalBasicDispatch With AC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")

    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 240, 0, 240, 240, 0, false)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 240, 0, 240, 240, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

# This Formulation is currently broken
@testset "ThermalMultiStart with ThermalBasicDispatch With DC - PF" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 240, 0, 48, 48, 96, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "ThermalMultiStart with ThermalBasicDispatch With AC - PF" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 288, 0, 96, 96, 96, false)
    psi_checkobjfun_test(model, GAEVF)
end

################################### No Minimum Dispatch tests ##############################
@testset "Thermal Dispatch NoMin With DC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 120, 0, 120, 120, 0, false)
    key = PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, ThermalStandard, "lb")
    moi_lbvalue_test(model, key, 0.0)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")

    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 120, 0, 120, 120, 0, false)
    key = PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, ThermalStandard, "lb")
    moi_lbvalue_test(model, key, 0.0)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal Dispatch NoMin With AC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 240, 0, 240, 240, 0, false)
    key = PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, ThermalStandard, "lb")
    moi_lbvalue_test(model, key, 0.0)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")

    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 240, 0, 240, 240, 0, false)
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
        export_pwl_vars=true,
        initialize_model=false,
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
    moi_tests(model, false, 120, 0, 168, 168, 0, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 120, 0, 120, 120, 0, false)
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
    moi_tests(model, false, 240, 0, 288, 288, 0, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 240, 0, 240, 240, 0, false)
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
    moi_tests(model, false, 240, 0, 96, 96, 96, false)
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
    moi_tests(model, false, 288, 0, 144, 144, 96, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

################################### ThermalMultiStart Testing ##############################

@testset "Thermal MultiStart with MultiStart UC and DC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(ActiveRangeICConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(StartTypeConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(MustRunConstraint, PSY.ThermalMultiStart),
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
        PSI.ConstraintKey(StartupInitialConditionConstraint, PSY.ThermalMultiStart, "lb"),
        PSI.ConstraintKey(StartupInitialConditionConstraint, PSY.ThermalMultiStart, "ub"),
    ]
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    no_less_than = Dict(true => 334, false => 282)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 528, 0, no_less_than[false], 108, 192, true)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with MultiStart UC and AC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(ActiveRangeICConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(StartTypeConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(MustRunConstraint, PSY.ThermalMultiStart),
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
        PSI.ConstraintKey(StartupInitialConditionConstraint, PSY.ThermalMultiStart, "lb"),
        PSI.ConstraintKey(StartupInitialConditionConstraint, PSY.ThermalMultiStart, "ub"),
    ]
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    no_less_than = Dict(true => 382, false => 330)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 576, 0, no_less_than[false], 156, 192, true)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

################################ Thermal Compact UC Testing ################################
@testset "Thermal Standard with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 480, 0, 480, 120, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 384, 0, 240, 48, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal Standard with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 600, 0, 600, 240, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 432, 0, 288, 96, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

################################ Thermal Basic Compact UC Testing ################################
@testset "Thermal Standard with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 480, 0, 240, 120, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 384, 0, 96, 48, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal Standard with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 600, 0, 360, 240, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 432, 0, 144, 96, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

############################ Thermal Compact Dispatch Testing ##############################
@testset "Thermal Standard with Compact Dispatch and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves=true)
    moi_tests(model, true, 120, 0, 144, 144, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact Dispatch and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib)
    mock_construct_device!(model, device_model; built_for_recurrent_solves=true)
    moi_tests(model, true, 240, 0, 96, 96, 96, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal Standard with Compact Dispatch and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves=true)
    moi_tests(model, true, 240, 0, 264, 264, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact Dispatch and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib)
    mock_construct_device!(model, device_model; built_for_recurrent_solves=true)
    moi_tests(model, true, 288, 0, 144, 144, 96, false)
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
        optimizer=HiGHS_optimizer,
        initialize_model=false,
    )
    @test build!(ED; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(ED, false, 10, 0, 15, 15, 5, false)
    psi_checksolve_test(ED, [MOI.OPTIMAL], 11191.00)
end

# Testing Duration Constraints
@testset "Solving UC with CopperPlate for testing Duration Constraints" begin
    template = get_thermal_standard_uc_template()
    UC = DecisionModel(
        UnitCommitmentProblem,
        template,
        PSB.build_system(PSITestSystems, "c_duration_test");
        optimizer=HiGHS_optimizer,
        initialize_model=false,
    )
    @test build!(UC; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(UC, false, 56, 0, 56, 14, 21, true)
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8223.50)
end

## PWL linear Cost implementation test
@testset "Solving UC with CopperPlate testing Convex PWL" begin
    template = get_thermal_standard_uc_template()
    UC = DecisionModel(
        UnitCommitmentProblem,
        template,
        PSB.build_system(PSITestSystems, "c_linear_pwl_test");
        optimizer=HiGHS_optimizer,
        initialize_model=false,
    )
    @test build!(UC; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(UC, false, 32, 0, 8, 4, 14, true)
    psi_checksolve_test(UC, [MOI.OPTIMAL], 9336.736919354838)
end

@testset "Solving UC with CopperPlate testing PWL-SOS2 implementation" begin
    template = get_thermal_standard_uc_template()
    UC = DecisionModel(
        UnitCommitmentProblem,
        template,
        PSB.build_system(PSITestSystems, "c_sos_pwl_test");
        optimizer=cbc_optimizer,
        initialize_model=false,
    )
    @test build!(UC; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(UC, false, 32, 0, 8, 4, 14, true)
    # Cbc can have reliability issues with SoS. The objective function target in the this
    # test was calculated with CPLEX do not change if Cbc gets a bad result
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8500.0, 10.0)
end

@testset "UC with MarketBid Cost in ThermalGenerators" begin
    template = get_thermal_standard_uc_template()
    set_device_model!(
        template,
        DeviceModel(ThermalMultiStart, ThermalMultiStartUnitCommitment),
    )
    UC = DecisionModel(
        UnitCommitmentProblem,
        template,
        PSB.build_system(PSITestSystems, "c_market_bid_cost");
        optimizer=cbc_optimizer,
        initialize_model=false,
    )
    @test build!(UC; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(UC, false, 38, 0, 16, 8, 16, true)
end

@testset "Solving UC Models with Linear Networks" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys5_dc = PSB.build_system(PSITestSystems, "c_sys5_dc")
    systems = [c_sys5, c_sys5_dc]
    networks = [DCPPowerModel, NFAPowerModel, StandardPTDFModel, CopperPlatePowerModel]
    commitment_models = [ThermalStandardUnitCommitment, ThermalCompactUnitCommitment]
    PTDF_ref = IdDict{System, PTDF}(c_sys5 => PTDF(c_sys5), c_sys5_dc => PTDF(c_sys5_dc))

    for net in networks, sys in systems, model in commitment_models
        template =
            get_thermal_dispatch_template_network(NetworkModel(net, PTDF=PTDF_ref[sys]))
        set_device_model!(template, ThermalStandard, model)
        UC = DecisionModel(template, sys; optimizer=HiGHS_optimizer)
        @test build!(UC; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
        psi_checksolve_test(UC, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED], 340000, 100000)
    end
end

@testset "Test Feedforwards to ThermalStandard with ThermalStandardDispatch" begin
    device_model = DeviceModel(ThermalStandard, ThermalStandardDispatch)
    ff_sc = SemiContinuousFeedforward(
        component_type=ThermalStandard,
        source=OnVariable,
        affected_values=[ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(
        component_type=ThermalStandard,
        source=ActivePowerVariable,
        affected_values=[ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves=true)
    moi_tests(model, true, 120, 0, 264, 144, 0, false)
end

@testset "Test Feedforwards to ThermalStandard with ThermalBasicDispatch" begin
    device_model = DeviceModel(ThermalStandard, ThermalBasicDispatch)
    ff_sc = SemiContinuousFeedforward(
        component_type=ThermalStandard,
        source=OnVariable,
        affected_values=[ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(
        component_type=ThermalStandard,
        source=ActivePowerVariable,
        affected_values=[ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves=true)
    moi_tests(model, true, 120, 0, 240, 120, 0, false)
end

@testset "Test Feedforwards to ThermalStandard with ThermalCompactDispatch" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    ff_sc = SemiContinuousFeedforward(
        component_type=ThermalStandard,
        source=OnVariable,
        affected_values=[PowerAboveMinimumVariable],
    )

    ff_ub = UpperBoundFeedforward(
        component_type=ThermalStandard,
        source=PSI.PowerAboveMinimumVariable,
        affected_values=[PSI.PowerAboveMinimumVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves=true)
    moi_tests(model, true, 120, 0, 264, 144, 0, false)
end

@testset "Test Feedforwards to ThermalMultiStart with ThermalStandardDispatch" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalStandardDispatch)
    ff_sc = SemiContinuousFeedforward(
        component_type=ThermalMultiStart,
        source=OnVariable,
        affected_values=[ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(
        component_type=ThermalMultiStart,
        source=ActivePowerVariable,
        affected_values=[ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves=true)
    moi_tests(model, true, 240, 0, 144, 96, 96, false)
end

@testset "Test Feedforwards to ThermalMultiStart with ThermalBasicDispatch" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicDispatch)
    ff_sc = SemiContinuousFeedforward(
        component_type=ThermalMultiStart,
        source=OnVariable,
        affected_values=[ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(
        component_type=ThermalMultiStart,
        source=ActivePowerVariable,
        affected_values=[ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves=true)
    moi_tests(model, true, 240, 0, 96, 48, 96, false)
end

@testset "Test Feedforwards to ThermalMultiStart with ThermalCompactDispatch" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch)
    ff_sc = SemiContinuousFeedforward(
        component_type=ThermalMultiStart,
        source=OnVariable,
        affected_values=[PSI.PowerAboveMinimumVariable],
    )

    ff_ub = UpperBoundFeedforward(
        component_type=ThermalMultiStart,
        source=PSI.PowerAboveMinimumVariable,
        affected_values=[PSI.PowerAboveMinimumVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves=true)
    moi_tests(model, true, 240, 0, 144, 96, 96, false)
end
