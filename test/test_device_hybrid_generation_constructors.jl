@testset "Hybrid DCPLossLess with BasicHybridDispatch formulation" begin
    device_model = DeviceModel(HybridSystem, BasicHybridDispatch)
    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid")

    # Parameters Testing
    model =
        DecisionModel(MockOperationProblem, DCPPowerModel, sys)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 672, 0, 384, 336, 192, true)
    psi_checkobjfun_test(model, GAEVF)

end

@testset "Hybrid ACPPowerModel with BasicHybridDispatch formulation" begin
    device_model = DeviceModel(HybridSystem, BasicHybridDispatch)
    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, sys)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 864, 0, 672, 624, 288, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hybrid DCPLossLess BasicHybridDispatch" begin
    device_model = DeviceModel(HybridSystem, StandardHybridDispatch)
    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid")

    # Parameters Testing
    model =
        DecisionModel(MockOperationProblem, DCPPowerModel, sys)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 672, 0, 384, 336, 192, true)
    psi_checkobjfun_test(model, GAEVF)

end

@testset "Hybrid ACPPowerModel with StandardHybridDispatch formulation" begin
    device_model = DeviceModel(HybridSystem, StandardHybridDispatch)
    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, sys)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 864, 0, 672, 624, 288, true)
    psi_checkobjfun_test(model, GAEVF)
end
