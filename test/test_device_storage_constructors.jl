@testset "Storage data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type GenericBattery, consider changing the device models"
    model = DeviceModel(GenericBattery, BookKeeping)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        model,
        model,
    )
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        model,
        model,
    )
end

@testset "Storage Basic Storage With DC - PF" begin
    model = DeviceModel(GenericBattery, BookKeeping)
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_bat)
    mock_construct_device!(model, model)
    moi_tests(model, false, 72, 0, 72, 72, 24, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Storage Basic Storage With AC - PF" begin
    model = DeviceModel(GenericBattery, BookKeeping)
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_bat)
    mock_construct_device!(model, model)
    moi_tests(model, false, 96, 0, 96, 96, 24, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Storage with Reservation DC - PF" begin
    model = DeviceModel(GenericBattery, BookKeepingwReservation)
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_bat)
    mock_construct_device!(model, model)
    moi_tests(model, false, 96, 0, 72, 72, 24, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Storage with Reservation With AC - PF" begin
    model = DeviceModel(GenericBattery, BookKeepingwReservation)
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_bat)
    mock_construct_device!(model, model)
    moi_tests(model, false, 120, 0, 96, 96, 24, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Storage with Reservation DC - PF" begin
    model = DeviceModel(GenericBattery, BatteryAncillaryServices)
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_bat)
    mock_construct_device!(model, model)
    moi_tests(model, false, 96, 0, 168, 72, 24, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Storage with Reservation With AC - PF" begin
    model = DeviceModel(GenericBattery, BatteryAncillaryServices)
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_bat)
    mock_construct_device!(model, model)
    moi_tests(model, false, 120, 0, 192, 96, 24, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "BatteryEMS with EnergyTarget with DC - PF" begin
    model = DeviceModel(BatteryEMS, EnergyTarget)
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat_ems")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_bat)
    mock_construct_device!(model, model)
    moi_tests(model, false, 144, 0, 72, 72, 48, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "BatteryEMS with EnergyTarget With AC - PF" begin
    model = DeviceModel(BatteryEMS, EnergyTarget)
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat_ems")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_bat)
    mock_construct_device!(model, model)
    moi_tests(model, false, 168, 0, 96, 96, 48, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "BatteryEMS with EnergyTarget Formulations (energy target - cases 1b-2b" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, BatteryEMS, EnergyTarget)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    c_sys5 = PSB.build_system(PSITestSystems, "batt_test_case_b_sys")
    model =
        DecisionModel(EconomicDispatchProblem, template, c_sys5; optimizer = Cbc_optimizer)
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(model, true, 21, 0, 12, 9, 9, true)
    psi_checksolve_test(model, [MOI.OPTIMAL], 5811.0, 10.0)
end

@testset "BatteryEMS with EnergyTarget Formulations (energy target - cases 1c-2c" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, BatteryEMS, EnergyTarget)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    c_sys5 = PSB.build_system(PSITestSystems, "batt_test_case_c_sys")

    model =
        DecisionModel(EconomicDispatchProblem, template, c_sys5; optimizer = Cbc_optimizer)
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(model, true, 21, 0, 12, 9, 9, true)
    psi_checksolve_test(model, [MOI.OPTIMAL], -63.0, 10.0)
end

@testset "BatteryEMS with EnergyTarget Formulations (energy target - cases 1d-2d" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, BatteryEMS, EnergyTarget)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    c_sys5 = PSB.build_system(PSITestSystems, "batt_test_case_d_sys")

    model =
        DecisionModel(EconomicDispatchProblem, template, c_sys5; optimizer = Cbc_optimizer)
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(model, true, 28, 0, 20, 16, 12, true)
    psi_checksolve_test(model, [MOI.OPTIMAL], -11118.0, 10.0)
end

@testset "BatteryEMS with EnergyTarget Formulations (energy target - cases 1e-2e" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, BatteryEMS, EnergyTarget)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    c_sys5 = PSB.build_system(PSITestSystems, "batt_test_case_e_sys")
    model =
        DecisionModel(EconomicDispatchProblem, template, c_sys5; optimizer = Cbc_optimizer)
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(model, true, 21, 0, 12, 9, 9, true)
    psi_checksolve_test(model, [MOI.OPTIMAL], 5547.0, 10.0)
end

@testset "BatteryEMS with EnergyTarget Formulations (energy target - cases 1f-2f" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, BatteryEMS, EnergyTarget)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    c_sys5 = PSB.build_system(PSITestSystems, "batt_test_case_f_sys")

    model =
        DecisionModel(EconomicDispatchProblem, template, c_sys5; optimizer = Cbc_optimizer)
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(model, true, 21, 0, 12, 9, 9, true)
    psi_checksolve_test(model, [MOI.OPTIMAL], -1825.0, 10.0)
end
