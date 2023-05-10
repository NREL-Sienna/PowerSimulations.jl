###################################
###### FIXED OUTPUT TESTS #########
###################################

@testset "Hydro DCPLossLess FixedOutput" begin
    device_model = DeviceModel(HydroDispatch, FixedOutput)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(model, device_model)
    moi_tests(model, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro DCPLossLess HydroEnergyReservoir with FixedOutput formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, FixedOutput)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

###################################
### RUN OF RIVER DISPATCH TESTS ###
###################################

@testset "Hydro DCPLossLess HydroDispatch with HydroDispatchRunOfRiver formulations" begin
    device_model = DeviceModel(HydroDispatch, HydroDispatchRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(model, device_model)
    moi_tests(model, 24, 0, 48, 24, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPPowerModel HydroDispatch with HydroDispatchRunOfRiver formulations" begin
    device_model = DeviceModel(HydroDispatch, HydroDispatchRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hy)
    mock_construct_device!(model, device_model)
    moi_tests(model, 48, 0, 72, 48, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchRunOfRiver formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, 24, 0, 48, 24, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroDispatchRunOfRiver formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, 48, 0, 72, 48, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

###################################
#### RUN OF RIVER COMMIT TESTS ####
###################################

@testset "Hydro DCPLossLess HydroDispatch with HydroCommitmentRunOfRiver formulations" begin
    device_model = DeviceModel(HydroDispatch, HydroCommitmentRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(model, device_model)
    moi_tests(model, 48, 0, 48, 24, 0, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPPowerModel HydroDispatch with HydroCommitmentRunOfRiver formulations" begin
    device_model = DeviceModel(HydroDispatch, HydroCommitmentRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hy)
    mock_construct_device!(model, device_model)
    moi_tests(model, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentRunOfRiver formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroCommitmentRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, 48, 0, 48, 24, 0, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroCommitmentRunOfRiver formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroCommitmentRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(model, GAEVF)
end
