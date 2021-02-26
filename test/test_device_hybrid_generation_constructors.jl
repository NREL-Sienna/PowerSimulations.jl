@testset "Hybrid DCPLossLess PhysicalCoupling" begin
    model = DeviceModel(HybridSystem, PhysicalCoupling)
    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid"; skip_serialization = true)

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        sys;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 624, 0, 624, 576, 288, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, sys)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 624, 0, 624, 576, 288, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        sys;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 26, 0, 26, 26, 12, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end


@testset "Hybrid DCPLossLess FinancialCoupling" begin
    model = DeviceModel(HybridSystem, FinancialCoupling)
    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid"; skip_serialization = true)

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        sys;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 624, 0, 432, 432, 288, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, sys)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 624, 0, 432, 384, 288, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        sys;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 26, 0, 18, 18, 12, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hybrid DCPLossLess StandardHybridFormulation" begin
    model = DeviceModel(HybridSystem, StandardHybridFormulation)
    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid"; skip_serialization = true)

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        sys;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 624, 0, 624, 576, 288, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, sys)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 624, 0, 624, 576, 288, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        sys;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 26, 0, 26, 26, 12, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end
