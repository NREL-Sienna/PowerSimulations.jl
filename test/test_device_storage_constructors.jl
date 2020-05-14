@testset "Storage data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type GenericBattery, consider changing the device models"
    model = DeviceModel(GenericBattery, BookKeeping)
    c_sys5 = build_c_sys5()
    c_sys14 = build_c_sys14()
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5)
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Storage, model)
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14)
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Storage, model)
end

@testset "Storage Basic Storage With DC - PF" begin
    model = DeviceModel(GenericBattery, BookKeeping)
    c_sys5_bat = build_c_sys5_bat()
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 72, 0, 72, 72, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Storage Basic Storage With AC - PF" begin
    model = DeviceModel(GenericBattery, BookKeeping)
    c_sys5_bat = build_c_sys5_bat()
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 96, 0, 96, 96, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Storage with Reservation DC - PF" begin
    model = DeviceModel(GenericBattery, BookKeepingwReservation)
    c_sys5_bat = build_c_sys5_bat()
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 96, 0, 72, 72, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Storage with Reservation With AC - PF" begin
    model = DeviceModel(GenericBattery, BookKeepingwReservation)
    c_sys5_bat = build_c_sys5_bat()
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_bat)
    construct_device!(op_problem, :Storage, model)
    moi_tests(op_problem, false, 120, 0, 96, 96, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)
end
