#@testset "Hybrid DCPLossLess with BasicHybridDispatch formulation" begin
#    device_model = DeviceModel(HybridSystem, BasicHybridDispatch)
#    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid")
#
#    # Parameters Testing
#    model =
#        DecisionModel(MockOperationProblem, DCPPowerModel, sys; store_variable_names=true)
#    mock_construct_device!(model, device_model)
#    moi_tests(model, 816, 0, 480, 240, 192, true)
#    psi_checkobjfun_test(model, GAEVF)
#end
#
#@testset "Hybrid ACPPowerModel with BasicHybridDispatch formulation" begin
#    device_model = DeviceModel(HybridSystem, BasicHybridDispatch)
#    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid")
#
#    # No Parameters Testing
#    model = DecisionModel(MockOperationProblem, ACPPowerModel, sys)
#    mock_construct_device!(model, device_model)
#    moi_tests(model, 1152, 0, 816, 576, 288, true)
#    psi_checkobjfun_test(model, GAEVF)
#end
#
#@testset "Hybrid DCPLossLess BasicHybridDispatch" begin
#    device_model = DeviceModel(HybridSystem, StandardHybridDispatch)
#    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid")
#
#    # Parameters Testing
#    model = DecisionModel(MockOperationProblem, DCPPowerModel, sys)
#    mock_construct_device!(model, device_model)
#    moi_tests(model, 816, 0, 480, 240, 192, true)
#    psi_checkobjfun_test(model, GAEVF)
#end
#
#@testset "Hybrid ACPPowerModel with StandardHybridDispatch formulation" begin
#    device_model = DeviceModel(HybridSystem, StandardHybridDispatch)
#    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid")
#
#    # No Parameters Testing
#    model = DecisionModel(MockOperationProblem, ACPPowerModel, sys)
#    mock_construct_device!(model, device_model)
#    moi_tests(model, 1152, 0, 816, 576, 288, true)
#    psi_checkobjfun_test(model, GAEVF)
#end
