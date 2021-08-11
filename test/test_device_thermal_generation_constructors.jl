test_path = mktempdir()
@testset "ThermalGen data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type ThermalStandard, consider changing the device models"
    model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)
    c_sys5_re_only = PSB.build_system(PSITestSystems, "c_sys5_re_only")
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_re_only)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        op_problem,
        model,
    )
end

################################### Unit Commitment tests ##################################
@testset "Thermal UC With DC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.START, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalStandard),
    ]

    uc_constraint_names = [
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.DURATION_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.DURATION_DOWN, PSY.ThermalStandard),
    ]

    aux_vars_keys = [
        PSI.AuxVarKey(PSI.TimeDurationOff, ThermalStandard),
        PSI.AuxVarKey(PSI.TimeDurationOn, ThermalStandard),
    ]
    model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_uc)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 480, 0, 480, 120, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)
    psi_aux_var_test(op_problem, aux_vars_keys)

    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_uc;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 480, 0, 480, 120, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys14;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 480, 0, 240, 120, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal UC With AC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.START, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalStandard),
    ]
    uc_constraint_names = [
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.DURATION_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.DURATION_DOWN, PSY.ThermalStandard),
    ]

    aux_vars_keys = [
        PSI.AuxVarKey(PSI.TimeDurationOff, ThermalStandard),
        PSI.AuxVarKey(PSI.TimeDurationOn, ThermalStandard),
    ]

    model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_uc)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 600, 0, 600, 240, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)
    psi_aux_var_test(op_problem, aux_vars_keys)

    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_uc;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 600, 0, 600, 240, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys14;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 600, 0, 360, 240, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal MultiStart UC With DC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.START, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalMultiStart),
    ]
    uc_constraint_names = [
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.DURATION_UP, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.DURATION_DOWN, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(ThermalMultiStart, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5_uc;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 384, 0, 240, 48, 96, true)
        psi_constraint_test(op_problem, uc_constraint_names)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart UC With AC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.START, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalMultiStart),
    ]
    uc_constraint_names = [
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.DURATION_UP, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.DURATION_DOWN, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(ThermalMultiStart, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5_uc;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 432, 0, 288, 96, 96, true)
        psi_constraint_test(op_problem, uc_constraint_names)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

################################### Basic Unit Commitment tests ############################
@testset "Thermal Basic UC With DC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.START, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalStandard),
    ]
    model = DeviceModel(ThermalStandard, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_uc)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_uc;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys14;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 480, 0, 240, 120, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal Basic UC With AC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.START, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalStandard),
    ]
    model = DeviceModel(ThermalStandard, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_uc)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_uc;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys14;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 600, 0, 360, 240, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal MultiStart Basic UC With DC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.START, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(ThermalMultiStart, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5_uc;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 384, 0, 96, 48, 96, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart Basic UC With AC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.START, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(ThermalMultiStart, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5_uc;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 432, 0, 144, 96, 96, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

################################### Basic Dispatch tests ###################################
@testset "Thermal Dispatch With DC - PF" begin
    model = DeviceModel(ThermalStandard, ThermalDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 120, 0, 120, 120, 0, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys14;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 120, 0, 120, 120, 0, false)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal Dispatch With AC - PF" begin
    model = DeviceModel(ThermalStandard, ThermalDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 240, 0, 240, 240, 0, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys14;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 240, 0, 240, 240, 0, false)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "ThermalMultiStart Dispatch With DC - PF" begin
    model = DeviceModel(ThermalMultiStart, ThermalDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 240, 0, 48, 48, 48, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalMultiStart Dispatch With AC - PF" begin
    model = DeviceModel(ThermalMultiStart, ThermalDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 288, 0, 96, 96, 48, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

################################### No Minimum Dispatch tests ##############################

@testset "Thermal Dispatch NoMin With DC - PF" begin
    model = DeviceModel(ThermalStandard, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 120, 0, 120, 120, 0, false)
        moi_lbvalue_test(op_problem, :P_lb__ThermalStandard__RangeConstraint, 0.0)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys14;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 120, 0, 120, 120, 0, false)
        moi_lbvalue_test(op_problem, :P_lb__ThermalStandard__RangeConstraint, 0.0)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal Dispatch NoMin With AC - PF" begin
    model = DeviceModel(ThermalStandard, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 240, 0, 240, 240, 0, false)
        moi_lbvalue_test(op_problem, :P_lb__ThermalStandard__RangeConstraint, 0.0)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys14;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 240, 0, 240, 240, 0, false)
        moi_lbvalue_test(op_problem, :P_lb__ThermalStandard__RangeConstraint, 0.0)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

# This Formulation is currently broken
#=
@testset "Thermal Dispatch NoMin With DC - PF" begin
    model = DeviceModel(ThermalMultiStart, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 240, 0, 48, 48, 48, false)
        moi_lbvalue_test(op_problem, :P_lb__ThermalMultiStart__RangeConstraint, 0.0)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalMultiStart Dispatch NoMin With AC - PF" begin
    model = DeviceModel(ThermalMultiStart, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 288, 0, 96, 96, 48, false)
        moi_lbvalue_test(op_problem, :P_lb__ThermalMultiStart__RangeConstraint, 0.0)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end
=#
################################### Ramp Limited Testing ##################################
@testset "Thermal Ramp Limited Dispatch With DC - PF" begin
    constraint_names = [
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
    ]
    model = DeviceModel(ThermalStandard, ThermalRampLimited)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5_uc;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 120, 0, 216, 120, 0, false)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys14;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 120, 0, 120, 120, 0, false)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal Ramp Limited Dispatch With AC - PF" begin
    constraint_names = [
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
    ]
    model = DeviceModel(ThermalStandard, ThermalRampLimited)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5_uc;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 240, 0, 336, 240, 0, false)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys14;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 240, 0, 240, 240, 0, false)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal Ramp Limited Dispatch With DC - PF" begin
    constraint_names = [
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(ThermalMultiStart, ThermalRampLimited)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5_uc;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 240, 0, 144, 48, 48, false)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal Ramp Limited Dispatch With AC - PF" begin
    constraint_names = [
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(ThermalMultiStart, ThermalRampLimited)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5_uc;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 288, 0, 192, 96, 48, false)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

################################### ThermalMultiStart Testing ##################################

@testset "Thermal MultiStart with MultiStart UC and DC - PF" begin
    constraint_names = [
        PSI.make_constraint_name(PSI.ACTIVE_RANGE_IC, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.START_TYPE, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.MUST_RUN_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_WARM, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_HOT, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_UB, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    no_less_than = Dict(true => 334, false => 330)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5_pglib;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 528, 0, no_less_than[p], 106, 144, true)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart with MultiStart UC and AC - PF" begin
    constraint_names = [
        PSI.make_constraint_name(PSI.ACTIVE_RANGE_IC, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.START_TYPE, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.MUST_RUN_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_WARM, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_HOT, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_UB, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    no_less_than = Dict(true => 382, false => 378)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5_pglib;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 576, 0, no_less_than[p], 154, 144, true)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

################################### Thermal Compact UC Testing ##################################
@testset "Thermal Standard with Compact UC and DC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 480, 0, 595, 115, 120, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart with Compact UC and DC - PF" begin
    model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5_pglib;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 384, 0, 286, 46, 96, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal Standard with Compact UC and AC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 600, 0, 715, 235, 120, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart with Compact UC and AC - PF" begin
    model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5_pglib;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 432, 0, 334, 94, 96, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

################################### Thermal Compact Dispatch Testing ##################################

@testset "Thermal Standard with Compact Dispatch and DC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 120, 0, 168, 120, 0, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart with Compact Dispatch and DC - PF" begin
    model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            DCPPowerModel,
            c_sys5_pglib;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 240, 0, 144, 48, 48, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal Standard with Compact Dispatch and AC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 240, 0, 288, 240, 0, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart with Compact Dispatch and AC - PF" begin
    model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch)
    no_less_than = Dict(true => 382, false => 378)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            ACPPowerModel,
            c_sys5_pglib;
            use_parameters = p,
        )
        mock_construct_device!(op_problem, model)
        moi_tests(op_problem, p, 288, 0, 192, 96, 48, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

############################# MarketBidCost Tests with ThermalMultiStart #######################################

#TODO: Remove after this system is added to CaseBuilder
function build_bid_cost_test_system()
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_market_bid_cost")
    reserve_uc = VariableReserve{ReserveUp}("Reserve1", true, 0.6, 0.1)
    PSY.add_service!(
        c_sys5_uc,
        reserve_uc,
        PSY.get_components(PSY.ThermalMultiStart, c_sys5_uc),
    )
    init_time = DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S")
    time_stamps = collect(init_time:Hour(1):(init_time + Hour(1)))
    Reserve_ts = [
        TimeSeries.TimeArray(time_stamps, rand(2)),
        TimeSeries.TimeArray(time_stamps + Hour(1), rand(2)),
    ]
    for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(Reserve_ts[t])[1]
            forecast_data[ini_time] = Reserve_ts[t]
        end
        PSY.add_time_series!(
            c_sys5_uc,
            serv,
            PSY.Deterministic("requirement", forecast_data),
        )
    end
    generator = get_components_by_name(ThermalGen, c_sys5_uc, "115_STEAM_1")[1]
    service_data = Dict(init_time => ones(2) * 99, init_time + Hour(1) => ones(2) * 55)
    for s in generator.services
        forecast = IS.Deterministic(get_name(s), service_data, Hour(1))
        set_service_bid!(c_sys5_uc, generator, s, forecast)
    end
    return c_sys5_uc
end

@testset "Thermal MultiStart with MultiStart UC and DC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    constraint_names = [
        PSI.make_constraint_name(PSI.ACTIVE_RANGE_IC, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.START_TYPE, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.MUST_RUN_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_WARM, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_HOT, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_UB, PSY.ThermalMultiStart),
    ]
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment),
    )
    no_less_than = Dict(true => 14, false => 12)
    c_sys5_pglib = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_pglib; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 26, 0, no_less_than[p], 9, 11, true)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart with MultiStart UC and AC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    constraint_names = [
        PSI.make_constraint_name(PSI.ACTIVE_RANGE_IC, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.START_TYPE, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.MUST_RUN_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_WARM, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_HOT, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_UB, PSY.ThermalMultiStart),
    ]
    template = OperationsProblemTemplate(ACPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment),
    )
    no_less_than = Dict(true => 16, false => 14)
    c_sys5_pglib = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_pglib; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 30, 0, no_less_than[p], 11, 13, true)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart with Compact UC and DC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactUnitCommitment),
    )
    c_sys5_pglib = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_pglib; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 20, 0, 9, 3, 9, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart with Compact UC and AC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(ACPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactUnitCommitment),
    )
    c_sys5_pglib = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_pglib; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 24, 0, 11, 5, 11, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart with Standard UC  With DC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalMultiStart, PSI.ThermalStandardUnitCommitment),
    )

    c_sys5_uc = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 20, 0, 8, 4, 9, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart  Standard UC With AC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(ACPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalMultiStart, PSI.ThermalStandardUnitCommitment),
    )

    c_sys5_uc = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 24, 0, 10, 6, 11, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart Basic UC With DC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.START, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalMultiStart),
    ]
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalMultiStart, PSI.ThermalBasicUnitCommitment),
    )

    c_sys5_uc = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 20, 0, 4, 4, 9, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart Basic UC With AC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.START, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalMultiStart),
    ]
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalMultiStart, PSI.ThermalBasicUnitCommitment),
    )
    c_sys5_uc = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 20, 0, 4, 4, 9, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart with Compact Dispatch and DC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch),
    )
    c_sys5_pglib = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_pglib; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 14, 0, 2, 4, 7, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart with Compact Dispatch and AC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(ACPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch),
    )
    c_sys5_pglib = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_pglib; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 18, 0, 4, 6, 9, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalMultiStart Dispatch With DC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(template, DeviceModel(PSY.ThermalMultiStart, PSI.ThermalDispatch))
    c_sys5 = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 14, 0, 2, 4, 7, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalMultiStart Dispatch With AC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(ACPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(template, DeviceModel(PSY.ThermalMultiStart, PSI.ThermalDispatch))
    c_sys5 = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 18, 0, 4, 6, 9, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

############################# MarketBidCost Tests #######################################

#TODO: Remove after this system is added to CaseBuilder
function build_standard_bid_cost_test_system()
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_market_bid_cost")
    reserve_uc = VariableReserve{ReserveUp}("Reserve1", true, 0.6, 0.1)
    PSY.add_service!(
        c_sys5_uc,
        reserve_uc,
        PSY.get_components(PSY.ThermalStandard, c_sys5_uc),
    )
    init_time = DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S")
    time_stamps = collect(init_time:Hour(1):(init_time + Hour(1)))
    Reserve_ts = [
        TimeSeries.TimeArray(time_stamps, rand(2)),
        TimeSeries.TimeArray(time_stamps + Hour(1), rand(2)),
    ]
    for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(Reserve_ts[t])[1]
            forecast_data[ini_time] = Reserve_ts[t]
        end
        PSY.add_time_series!(
            c_sys5_uc,
            serv,
            PSY.Deterministic("requirement", forecast_data),
        )
    end
    generator = get_components_by_name(ThermalGen, c_sys5_uc, "Alta")[1]
    service_data = Dict(init_time => ones(2) * 99, init_time + Hour(1) => ones(2) * 55)
    for s in generator.services
        forecast = IS.Deterministic(get_name(s), service_data, Hour(1))
        set_service_bid!(c_sys5_uc, generator, s, forecast)
    end
    return c_sys5_uc
end

@testset "ThermalStandard with Compact UC and DC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactUnitCommitment),
    )
    c_sys5_pglib = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_pglib; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 20, 0, 5, 3, 8, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalStandard  with Compact UC and AC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(ACPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactUnitCommitment),
    )
    c_sys5_pglib = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_pglib; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 24, 0, 7, 5, 10, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalStandard with Standard UC  With DC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalStandard, PSI.ThermalStandardUnitCommitment),
    )

    c_sys5_uc = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 20, 0, 4, 4, 8, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalStandard Standard UC With AC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(ACPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalStandard, PSI.ThermalStandardUnitCommitment),
    )

    c_sys5_uc = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 24, 0, 6, 6, 10, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalStandard Basic UC With DC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.START, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalStandard),
    ]
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalStandard, PSI.ThermalBasicUnitCommitment),
    )

    c_sys5_uc = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 20, 0, 4, 4, 8, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalStandard Basic UC With AC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.START, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalStandard),
    ]
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalStandard, PSI.ThermalBasicUnitCommitment),
    )
    c_sys5_uc = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 20, 0, 4, 4, 8, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalStandard with Compact Dispatch and DC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch),
    )
    c_sys5_pglib = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_pglib; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 14, 0, 2, 4, 6, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalStandard with Compact Dispatch and AC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(ACPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(
        template,
        DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch),
    )
    c_sys5_pglib = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5_pglib; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 18, 0, 4, 6, 8, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalStandard Dispatch With DC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(DCPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(template, DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch))
    c_sys5 = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 14, 0, 2, 4, 6, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "ThermalStandard Dispatch With AC - PF, CostType-MarketBidCost and Service Bid Cost" begin
    template = OperationsProblemTemplate(ACPPowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_device_model!(template, DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch))
    c_sys5 = build_bid_cost_test_system()
    for p in [true, false]
        op_problem = OperationsProblem(template, c_sys5; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 18, 0, 4, 6, 8, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

############################# Model validation tests #######################################
@testset "Solving ED with CopperPlate for testing Ramping Constraints" begin
    ramp_test_sys = PSB.build_system(PSITestSystems, "c_ramp_test")
    template = OperationsProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, ThermalStandard, ThermalRampLimited)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    ED = OperationsProblem(
        EconomicDispatchProblem,
        template,
        ramp_test_sys;
        optimizer = Cbc_optimizer,
    )
    @test build!(ED; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(ED, false, 10, 0, 20, 10, 5, false)
    res = solve!(ED)
    psi_checksolve_test(ED, [MOI.OPTIMAL], 11191.00)
end

# Testing Duration Constraints
@testset "Solving UC with CopperPlate for testing Duration Constraints" begin
    template = get_thermal_standard_uc_template()
    UC = OperationsProblem(
        UnitCommitmentProblem,
        template,
        PSB.build_system(PSITestSystems, "c_duration_test");
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    @test build!(UC; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(UC, true, 56, 0, 56, 14, 21, true)
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8223.50)
end

## PWL linear Cost implementation test
@testset "Solving UC with CopperPlate testing Convex PWL" begin
    template = get_thermal_standard_uc_template()
    UC = OperationsProblem(
        UnitCommitmentProblem,
        template,
        PSB.build_system(PSITestSystems, "c_linear_pwl_test");
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    @test build!(UC; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(UC, true, 32, 0, 8, 4, 10, true)
    psi_checksolve_test(UC, [MOI.OPTIMAL], 9336.736919354838)
end

@testset "Solving UC with CopperPlate testing PWL-SOS2 implementation" begin
    template = get_thermal_standard_uc_template()
    UC = OperationsProblem(
        UnitCommitmentProblem,
        template,
        PSB.build_system(PSITestSystems, "c_sos_pwl_test");
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    @test build!(UC; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(UC, true, 32, 0, 8, 4, 14, true)
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8500.89716, 10.0)
end

@testset "UC with MarketBid Cost in ThermalGenerators" begin
    template = get_thermal_standard_uc_template()
    set_device_model!(
        template,
        DeviceModel(ThermalMultiStart, ThermalMultiStartUnitCommitment),
    )
    UC = OperationsProblem(
        UnitCommitmentProblem,
        template,
        PSB.build_system(PSITestSystems, "c_market_bid_cost");
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    @test build!(UC; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(UC, true, 38, 0, 18, 9, 13, true)
end

@testset "Operation ModelThermalDispatchNoMin - and PWL Non Convex" begin
    c_sys5_pwl_ed_nonconvex = PSB.build_system(PSITestSystems, "c_sys5_pwl_ed_nonconvex")
    template = get_thermal_dispatch_template_network()
    set_device_model!(template, DeviceModel(ThermalStandard, ThermalDispatchNoMin))
    op_problem = OperationsProblem(
        MockOperationProblem,
        CopperPlatePowerModel,
        c_sys5_pwl_ed_nonconvex;
        use_parameters = true,
        export_pwl_vars = true,
    )
    @test_throws IS.InvalidValue mock_construct_device!(
        op_problem,
        DeviceModel(ThermalStandard, ThermalDispatchNoMin),
    )
end

#TODO: Add test for newer UC models
@testset "Solving UC Models with Linear Networks" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys5_dc = PSB.build_system(PSITestSystems, "c_sys5_dc")
    parameters_value = [true, false]
    systems = [c_sys5, c_sys5_dc]
    networks = [DCPPowerModel, NFAPowerModel, StandardPTDFModel, CopperPlatePowerModel]
    PTDF_ref = IdDict{System, PTDF}(c_sys5 => PTDF(c_sys5), c_sys5_dc => PTDF(c_sys5_dc))

    for net in networks, p in parameters_value, sys in systems
        template = get_thermal_dispatch_template_network(net)
        set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
        UC = OperationsProblem(
            template,
            sys;
            optimizer = GLPK_optimizer,
            use_parameters = p,
            PTDF = PTDF_ref[sys],
        )
        @test build!(UC; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
        psi_checksolve_test(UC, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED], 340000, 100000)
    end
end
