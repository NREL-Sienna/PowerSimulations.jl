@testset "Renewable data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type HydroDispatch, consider changing the device models"
    model = DeviceModel(HydroDispatch, HydroDispatchRunOfRiver)
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5)
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Hydro, model)
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14)
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Hydro, model)
end


@testset "Hydro DCPLossLess FixedOutput" begin
    model = DeviceModel(HydroFix, HydroFixed)

    # Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy; use_parameters = true, use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy; use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro DCPLossLess HydroDispatch with HydroDispatchRunOfRiver formulations" begin
    model = DeviceModel(HydroDispatch, HydroDispatchRunOfRiver)

    # Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true, use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, true, 1, 0, 1, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 1, 0, 1, 1, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro DCPLossLess HydroDispatch with HydroDispatchReservoirFlow Formulations" begin
    model = DeviceModel(HydroDispatch, HydroDispatchReservoirFlow)

    # Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy_uc; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 24, 0, 25, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy_uc)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 24, 0, 25, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy_uc; use_parameters = true, use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, true, 1, 0, 2, 1, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy_uc; use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 1, 0, 2, 1, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end
#=
# All Hydro UC formulations are currently not supported
@testset "Hydro DCPLossLess HydroDispatch with HydroCommitmentRunOfRiver Formulations" begin
    model = DeviceModel(HydroDispatch, HydroCommitmentRunOfRiver)

    # Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 96, 0, 72, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 96, 0, 48, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true, use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, true, 4, 0, 3, 0, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 4, 0, 2, 1, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro DCPLossLess HydroDispatch with HydroCommitmentReservoirlFlow Formulations" begin
    model = DeviceModel(HydroDispatch, HydroCommitmentReservoirFlow)

    # Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 96, 0, 72, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 96, 0, 48, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true, use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, true, 4, 0, 3, 0, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 4, 0, 2, 1, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

end
=#

@testset "Hydro DCPLossLess HydroDispatch with HydroDispatchReservoirStorage Formulations" begin
    model = DeviceModel(HydroDispatch, HydroDispatchReservoirStorage)

    # Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 72, 0, 24, 24, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = false)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 72, 0, 24, 24, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true, use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, true, 3, 0, 1, 1, 1, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end

#=
# All Hydro UC formulations are currently not supported
@testset "Hydro DCPLossLess HydroDispatch with HydroCommitmentReservoirStorage Formulations" begin
    model = DeviceModel(HydroDispatch, HydroCommitmentReservoirStorage)

    # Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 96, 0, 72, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 96, 0, 48, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true, use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, true, 4, 0, 3, 0, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_forecast_data = false)
    construct_device!(op_problem, :Hydro, model);
    moi_tests(op_problem, false, 4, 0, 2, 1, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

end
=#
