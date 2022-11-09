@testset "Renewable DCPLossLess FullDispatch" begin
    device_model = DeviceModel(RenewableDispatch, RenewableFullDispatch)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_re)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 72, 0, 72, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Renewable ACPPower Full Dispatch" begin
    device_model = DeviceModel(RenewableDispatch, RenewableFullDispatch)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_re;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 144, 0, 144, 72, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Renewable DCPLossLess Constantpower_factor" begin
    device_model = DeviceModel(RenewableDispatch, RenewableConstantPowerFactor)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_re)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 72, 0, 72, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Renewable ACPPower Constantpower_factor" begin
    device_model = DeviceModel(RenewableDispatch, RenewableConstantPowerFactor)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_re;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 144, 0, 72, 0, 72, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Renewable DCPLossLess FixedOutput" begin
    device_model = DeviceModel(RenewableDispatch, FixedOutput)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_re;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Renewable ACPPowerModel FixedOutput" begin
    device_model = DeviceModel(RenewableDispatch, FixedOutput)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_re;)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end
