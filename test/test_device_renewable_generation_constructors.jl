@testset "Renewable data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type RenewableDispatch, consider changing the device models"
    model = DeviceModel(RenewableDispatch, RenewableFullDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")

    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        model,
        model,
    )
end

@testset "Renewable DCPLossLess FullDispatch" begin
    model = DeviceModel(RenewableDispatch, RenewableFullDispatch)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")

    #5 Bus testing case
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_re)
    mock_construct_device!(model, model)
    moi_tests(model, false, 72, 0, 72, 0, 0, false)

    psi_checkobjfun_test(model, GAEVF)

    # Using Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_re;)
    mock_construct_device!(model, model)
    moi_tests(model, true, 72, 0, 72, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)

    # No Forecast - No Parameters Testing
    model = DecisionModel(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_re;
        use_forecast_data = false,
    )
    mock_construct_device!(model, model)
    moi_tests(model, false, 3, 0, 3, 3, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Renewable ACPPower Full Dispatch" begin
    model = DeviceModel(RenewableDispatch, RenewableFullDispatch)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    for p in [true, false]
        model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_re;)
        mock_construct_device!(model, model)
        if p
            moi_tests(model, p, 144, 0, 144, 72, 0, false)
            psi_checkobjfun_test(model, GAEVF)
        else
            moi_tests(model, p, 144, 0, 144, 72, 0, false)

            psi_checkobjfun_test(model, GAEVF)
        end
    end
    # No Forecast Test
    model = DecisionModel(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_re;
        use_forecast_data = false,
        use_parameters = false,
    )
    mock_construct_device!(model, model)
    moi_tests(model, false, 6, 0, 6, 6, 0, false)

    psi_checkobjfun_test(model, GAEVF)
end

@testset "Renewable DCPLossLess Constantpower_factor" begin
    model = DeviceModel(RenewableDispatch, RenewableConstantPowerFactor)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")

    #5 Bus testing case
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_re)
    mock_construct_device!(model, model)
    moi_tests(model, false, 72, 0, 72, 0, 0, false)

    psi_checkobjfun_test(model, GAEVF)

    # Using Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_re;)
    mock_construct_device!(model, model)
    moi_tests(model, true, 72, 0, 72, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)

    # No Forecast - No Parameters Testing
    model = DecisionModel(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_re;
        use_forecast_data = false,
    )
    mock_construct_device!(model, model)
    moi_tests(model, false, 3, 0, 3, 3, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Renewable ACPPower Constantpower_factor" begin
    model = DeviceModel(RenewableDispatch, RenewableConstantPowerFactor)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    for p in [true, false]
        model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_re;)
        mock_construct_device!(model, model)
        if p
            moi_tests(model, p, 144, 0, 72, 0, 72, false)
            psi_checkobjfun_test(model, GAEVF)
        else
            moi_tests(model, p, 144, 0, 72, 0, 72, false)

            psi_checkobjfun_test(model, GAEVF)
        end
    end
    # No Forecast Test
    model = DecisionModel(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_re;
        use_forecast_data = false,
        use_parameters = false,
    )
    mock_construct_device!(model, model)
    moi_tests(model, false, 6, 0, 3, 3, 3, false)

    psi_checkobjfun_test(model, GAEVF)
end

@testset "Renewable DCPLossLess FixedOutput" begin
    model = DeviceModel(RenewableDispatch, FixedOutput)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    for p in [true, false]
        model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_re;)
        mock_construct_device!(model, model)
        if p
            moi_tests(model, p, 0, 0, 0, 0, 0, false)
            psi_checkobjfun_test(model, GAEVF)
        else
            moi_tests(model, p, 0, 0, 0, 0, 0, false)
            psi_checkobjfun_test(model, GAEVF)
        end
    end
end

@testset "Renewable ACPPowerModel FixedOutput" begin
    model = DeviceModel(RenewableDispatch, FixedOutput)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    for p in [true, false]
        model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_re;)
        mock_construct_device!(model, model)
        if p
            moi_tests(model, p, 0, 0, 0, 0, 0, false)
            psi_checkobjfun_test(model, GAEVF)
        else
            moi_tests(model, p, 0, 0, 0, 0, 0, false)
            psi_checkobjfun_test(model, GAEVF)
        end
    end
end
