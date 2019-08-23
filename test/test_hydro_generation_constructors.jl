@testset "Renewable data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type HydroDispatch, consider changing the device models"
    model = DeviceModel(PSY.HydroDispatch, PSI.HydroDispatchRunOfRiver)
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5)
    @test_logs (:warn, warn_message) construct_device!(op_model, :Hydro, model)
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys14)
    @test_logs (:warn, warn_message) construct_device!(op_model, :Hydro, model)
end


@testset "Hydro DCPLossLess FixedOutput" begin
    model = DeviceModel(PSY.HydroFix, PSI.HydroFixed)

    # Parameters Testing
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5_hy ; parameters = true)
    construct_device!(op_model, :Hydro, model)
    moi_tests(op_model, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_model, GAEVF)

    # No Parameters Testing
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5_hy)
    construct_device!(op_model, :Hydro, model);
    moi_tests(op_model, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_model, GAEVF)

    # No Forecast Testing
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5_hy ; parameters = true, forecast = false)
    construct_device!(op_model, :Hydro, model);
    moi_tests(op_model, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_model, GAEVF)

    # No Forecast - No Parameters Testing
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5_hy ; forecast = false)
    construct_device!(op_model, :Hydro, model);
    moi_tests(op_model, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_model, GAEVF)

end

#=
@testset " Hydro Tests" begin
    PSI.activepower_variables(ps_model, generators_hg, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.DCPlosslessForm, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.StandardACPForm, 1:24)
    PSI.reactivepower_variables(ps_model, generators_hg, 1:24)
    PSI.reactivepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.StandardACPForm, 1:24)
end

@testset " Hydro Tests" begin
    ps_model = PSI._canonical_model_init(length(sys5b.buses), nothing, PM.AbstractPowerFormulation, sys5b.time_periods)
    PSI.activepower_variables(ps_model, generators_hg, 1:24)
    PSI.commitment_variables(ps_model, generators_hg, 1:24);
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.DCPlosslessForm, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.StandardACPForm, 1:24)
    PSI.reactivepower_variables(ps_model, generators_hg, 1:24)
    PSI.reactivepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.StandardACPForm, 1:24)
end
=#