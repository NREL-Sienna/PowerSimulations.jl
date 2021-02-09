@testset "Renewable data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type HydroEnergyReservoir, consider changing the device models"
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        op_problem,
        model,
    )
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys14)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        op_problem,
        model,
    )
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hy;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hy)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hy;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 48, 0, 48, 24, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hy)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hy;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 48, 0, 48, 24, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 48, 0, 48, 24, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 24, 0, 1, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 24, 0, 1, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 48, 0, 1, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 48, 0, 1, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 60, 0, 24, 24, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_phes_ed)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 60, 0, 24, 24, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_phes_ed;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 72, 0, 24, 24, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_phes_ed)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 72, 0, 24, 24, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_phes_ed;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 48, 0, 25, 24, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 48, 0, 25, 24, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 72, 0, 49, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 72, 0, 49, 48, 0, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 72, 0, 0, 1, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 72, 0, 0, 1, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 96, 0, 0, 1, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 96, 0, 0, 1, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 96, 0, 24, 25, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 96, 0, 24, 25, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
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
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, true, 120, 0, 48, 49, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 120, 0, 48, 49, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        MockOperationProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    mock_construct_device!(op_problem, model)
    moi_tests(op_problem, false, 5, 0, 2, 3, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Solving ED Hydro System using Dispatch Run of River" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_hy")
    parameters_value = [true, false]
    networks = [ACPPowerModel, DCPPowerModel]

    test_results = Dict{Any, Float64}(ACPPowerModel => 12414.0, DCPPowerModel => 12218.0)

    for net in networks, p in parameters_value
        @info("Test solve HydroRoR ED with $(net) network")
        @testset "HydroRoR ED model $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net)
            set_device_model!(template, ThermalStandard, ThermalDispatch)
            set_device_model!(template, PowerLoad, StaticPowerLoad)
            set_device_model!(template, HydroDispatch, HydroDispatchRunOfRiver)
            set_device_model!(template, Transformer2W, StaticBranch)
            set_device_model!(template, TapTransformer, StaticBranch)
            set_device_model!(template, Line, StaticBranch)

            ED = OperationsProblem(
                EconomicDispatchProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
                use_parameters = true,
            )
            @test build!(ED; output_dir = mktempdir(cleanup = true)) ==
                  PSI.BuildStatus.BUILT
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[net],
                1000,
            )
        end
    end
end

@testset "Solving ED Hydro System using Commitment Run of River" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_hy")
    parameters_value = [true, false]
    net = DCPPowerModel

    template = OperationsProblemTemplate(net)
    set_device_model!(template, ThermalStandard, ThermalDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, HydroDispatch, HydroCommitmentRunOfRiver)
    set_device_model!(template, Transformer2W, StaticBranch)
    set_device_model!(template, TapTransformer, StaticBranch)
    set_device_model!(template, Line, StaticBranch)

    for p in parameters_value
        @testset "HydroRoR ED model $(net) and use_parameters = $(p)" begin
            ED = OperationsProblem(
                UnitCommitmentProblem,
                template,
                sys;
                optimizer = GLPK_optimizer,
                use_parameters = p,
            )
            @test build!(ED; output_dir = mktempdir(cleanup = true)) ==
                  PSI.BuildStatus.BUILT
            psi_checksolve_test(ED, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED], 12218.0, 1000)
        end
    end
end

@testset "Solving ED Hydro System using Dispatch with Reservoir" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_hyd")
    parameters_value = [true, false]
    networks = [ACPPowerModel, DCPPowerModel]
    models = [HydroDispatchReservoirBudget, HydroDispatchReservoirStorage]
    test_results = Dict{Any, Float64}(
        (ACPPowerModel, HydroDispatchReservoirBudget) => 338977.0,
        (DCPPowerModel, HydroDispatchReservoirBudget) => 337646.0,
        (ACPPowerModel, HydroDispatchReservoirStorage) => 303157.0,
        (DCPPowerModel, HydroDispatchReservoirStorage) => 301826.0,
    )
    parameters_value = [true, false]

    for net in networks, mod in models, p in parameters_value
        @testset "$(mod) ED model on $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net)
            set_device_model!(template, ThermalStandard, ThermalDispatch)
            set_device_model!(template, PowerLoad, StaticPowerLoad)
            set_device_model!(template, HydroEnergyReservoir, mod)
            set_device_model!(template, Transformer2W, StaticBranch)
            set_device_model!(template, TapTransformer, StaticBranch)
            set_device_model!(template, Line, StaticBranch)

            ED = OperationsProblem(
                EconomicDispatchProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
                use_parameters = p,
            )
            @test build!(ED; output_dir = mktempdir(cleanup = true)) ==
                  PSI.BuildStatus.BUILT
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[(net, mod)],
                10000,
            )
        end
    end
end

@testset "Solving ED Hydro System using Commitment with Reservoir" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_hyd")
    parameters_value = [true, false]
    net = DCPPowerModel
    models = [HydroCommitmentReservoirBudget, HydroCommitmentReservoirStorage]
    test_results = Dict{Any, Float64}(
        HydroCommitmentReservoirBudget => 337646.0,
        HydroCommitmentReservoirStorage => 301826.0,
    )

    for mod in models, p in parameters_value
        @testset "$(mod) ED model on $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net)
            set_device_model!(template, ThermalStandard, ThermalDispatch)
            set_device_model!(template, PowerLoad, StaticPowerLoad)
            set_device_model!(template, HydroEnergyReservoir, mod)
            set_device_model!(template, Transformer2W, StaticBranch)
            set_device_model!(template, TapTransformer, StaticBranch)
            set_device_model!(template, Line, StaticBranch)

            ED = OperationsProblem(
                UnitCommitmentProblem,
                template,
                sys;
                optimizer = GLPK_optimizer,
                use_parameters = p,
            )
            @test build!(ED; output_dir = mktempdir(cleanup = true)) ==
                  PSI.BuildStatus.BUILT
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[mod],
                10000,
            )
        end
    end
end
