@testset "Renewable data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type HydroDispatch, consider changing the device models"
    model = DeviceModel(PSY.HydroDispatch, PSI.HydroDispatchRunOfRiver)
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5)
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Hydro, model)
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14)
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Hydro, model)
end


@testset "Hydro DCPLossLess FixedOutput" begin
    model = DeviceModel(PSY.HydroFix, PSI.HydroFixed)

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
    model = DeviceModel(PSY.HydroDispatch, PSI.HydroDispatchRunOfRiver)

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
    moi_tests(op_problem, false, 1, 1, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end

# @testset "Hydro DCPLossLess HydroDispatch with HydroDispatchSeasonalFlow Formulations" begin
#     model = DeviceModel(PSY.HydroDispatch, PSI.HydroDispatchSeasonalFlow)

#     # Parameters Testing
#     op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
#     construct_device!(op_problem, :Hydro, model)
#     moi_tests(op_problem, true, 24, 0, 24, 0, 0, false)
#     psi_checkobjfun_test(op_problem, GAEVF)

#     # No Parameters Testing
#     op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd)
#     construct_device!(op_problem, :Hydro, model);
#     moi_tests(op_problem, false, 24, 0, 24, 0, 0, false)
#     psi_checkobjfun_test(op_problem, GAEVF)

#     # No Forecast Testing
#     op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true, use_forecast_data = false)
#     construct_device!(op_problem, :Hydro, model);
#     moi_tests(op_problem, true, 1, 0, 1, 0, 0, false)
#     psi_checkobjfun_test(op_problem, GAEVF)

#     # No Forecast - No Parameters Testing
#     op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_forecast_data = false)
#     construct_device!(op_problem, :Hydro, model);
#     moi_tests(op_problem, false, 1, 1, 0, 0, 0, false)
#     psi_checkobjfun_test(op_problem, GAEVF)

# end

@testset "Hydro DCPLossLess HydroDispatch with HydroCommitmentRunOfRiver Formulations" begin
    model = DeviceModel(PSY.HydroDispatch, PSI.HydroCommitmentRunOfRiver)

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

@testset "Hydro DCPLossLess HydroDispatch with HydroCommitmentSeasonalFlow Formulations" begin
    model = DeviceModel(PSY.HydroDispatch, PSI.HydroCommitmentSeasonalFlow)

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
#=
@testset " Hydro Tests" begin
    PSI.activepower_variables(ps_model, generators_hg, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, DCPPowerModel, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, ACPPowerModel, 1:24)
    PSI.reactivepower_variables(ps_model, generators_hg, 1:24)
    PSI.reactivepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, ACPPowerModel, 1:24)
end

@testset " Hydro Tests" begin
    ps_model = PSI._canonical_init(length(sys5b.buses), nothing, PM.AbstractPowerModel, sys5b.time_periods)
    PSI.activepower_variables(ps_model, generators_hg, 1:24)
    PSI.commitment_variables(ps_model, generators_hg, 1:24);
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, DCPPowerModel, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, ACPPowerModel, 1:24)
    PSI.reactivepower_variables(ps_model, generators_hg, 1:24)
    PSI.reactivepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, ACPPowerModel, 1:24)
end
=#
