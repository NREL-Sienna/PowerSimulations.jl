@testset "Renewable data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type HydroEnergyReservoir, consider changing the device models"
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_logs (:warn, warn_message) mock_construct_device!(op_problem, :Hydro, model)
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys14)
    @test_logs (:warn, warn_message) mock_construct_device!(op_problem, :Hydro, model)
end

###################################
###### FIXED OUTPUT TESTS #########
###################################

@testset "Hydro DCPLossLess FixedOutput" begin
    model = DeviceModel(HydroDispatch, FixedOutput)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hy;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hy;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro DCPLossLess HydroEnergyReservoir with FixedOutput formulations" begin
    model = DeviceModel(HydroEnergyReservoir, FixedOutput)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

###################################
### RUN OF RIVER DISPATCH TESTS ###
###################################

@testset "Hydro DCPLossLess HydroDispatch with HydroDispatchRunOfRiver formulations" begin
    model = DeviceModel(HydroDispatch, HydroDispatchRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hy;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro ACPPowerModel HydroDispatch with HydroDispatchRunOfRiver formulations" begin
    model = DeviceModel(HydroDispatch, HydroDispatchRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hy;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hy)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hy;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 2, 0, 2, 2, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchRunOfRiver formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 1, 0, 1, 1, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroDispatchRunOfRiver formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 2, 0, 2, 2, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

###################################
#### RUN OF RIVER COMMIT TESTS ####
###################################

@testset "Hydro DCPLossLess HydroDispatch with HydroCommitmentRunOfRiver formulations" begin
    model = DeviceModel(HydroDispatch, HydroCommitmentRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hy;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 48, 0, 48, 24, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 48, 0, 48, 24, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro ACPPowerModel HydroDispatch with HydroCommitmentRunOfRiver formulations" begin
    model = DeviceModel(HydroDispatch, HydroCommitmentRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hy;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hy)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hy;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 3, 0, 2, 2, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentRunOfRiver formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 48, 0, 48, 24, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 48, 0, 48, 24, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 2, 0, 1, 1, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroCommitmentRunOfRiver formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 3, 0, 2, 2, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

#########################################
#### RESERVOIR BUDGET DISPATCH TESTS ####
#########################################

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchReservoirBudget Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirBudget)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 24, 0, 1, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 24, 0, 1, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 1, 0, 1, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroDispatchReservoirBudget Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirBudget)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 48, 0, 1, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 48, 0, 1, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 2, 0, 1, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

#########################################
#### PUMPED STORAGE DISPATCH TESTS ####
#########################################

@testset "Hydro DCPLossLess HydroPumpedStorage with HydroDispatchPumpedStorage Formulations" begin
    model = DeviceModel(HydroPumpedStorage, HydroDispatchPumpedStorage)
    c_sys5_phes_ed = PSB.build_system(PSITestSystems, "c_sys5_phes_ed")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_phes_ed;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :PHES, model)
    moi_tests(op_problem, true, 60, 0, 24, 24, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_phes_ed)
    mock_construct_device!(op_problem, :PHES, model)
    moi_tests(op_problem, false, 60, 0, 24, 24, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_phes_ed;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :PHES, model)
    moi_tests(op_problem, false, 5, 0, 2, 2, 2, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro DCPLossLess HydroPumpedStorage with HydroDispatchPumpedStoragewReservation Formulations" begin
    model = DeviceModel(HydroPumpedStorage, HydroDispatchPumpedStoragewReservation)
    c_sys5_phes_ed = PSB.build_system(PSITestSystems, "c_sys5_phes_ed")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_phes_ed;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :PHES, model)
    moi_tests(op_problem, true, 72, 0, 24, 24, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_phes_ed)
    mock_construct_device!(op_problem, :PHES, model)
    moi_tests(op_problem, false, 72, 0, 24, 24, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_phes_ed;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :PHES, model)
    moi_tests(op_problem, false, 6, 0, 2, 2, 2, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

#########################################
### RESERVOIR BUDGET COMMITMENT TESTS ###
#########################################

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentReservoirBudget Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirBudget)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 48, 0, 25, 24, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 48, 0, 25, 24, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 2, 0, 2, 1, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroCommitmentReservoirBudget Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirBudget)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 72, 0, 49, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 72, 0, 49, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 3, 0, 3, 2, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

#########################################
### RESERVOIR STORAGE DISPATCH TESTS ####
#########################################

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirStorage)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 72, 0, 0, 1, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 72, 0, 0, 1, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 3, 0, 0, 1, 1, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro ACPLossLess HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirStorage)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 96, 0, 0, 1, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 96, 0, 0, 1, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 4, 0, 0, 1, 1, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

#########################################
### RESERVOIR STORAGE COMMITMENT TESTS ##
#########################################

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirStorage)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 96, 0, 24, 25, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 96, 0, 24, 25, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 4, 0, 1, 2, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro ACPLossLess HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirStorage)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 120, 0, 48, 49, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 120, 0, 48, 49, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 5, 0, 2, 3, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

#=
# All Hydro UC formulations are currently not supported
@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentRunOfRiver Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentRunOfRiver)

    # Parameters Testing
    op_problem =
        OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 96, 0, 72, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 96, 0, 48, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 4, 0, 3, 0, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 4, 0, 2, 1, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentReservoirlFlow Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirFlow)

    # Parameters Testing
    op_problem =
        OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 96, 0, 72, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 96, 0, 48, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 4, 0, 3, 0, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 4, 0, 2, 1, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirStorage)
    c_sys5_hyd = build_system("c_sys5_hyd")

    # Parameters Testing
    op_problem =
        OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 72, 0, 24, 24, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 72, 0, 24, 24, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end
=#

#=
# All Hydro UC formulations are currently not supported
@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentReservoirStorage Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirStorage)

    # Parameters Testing
    op_problem =
        OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 96, 0, 72, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 96, 0, 48, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 4, 0, 3, 0, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 4, 0, 2, 1, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

end
=#
