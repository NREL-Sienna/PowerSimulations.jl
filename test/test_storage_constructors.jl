@testset "Storage data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type GenericBattery, consider changing the device models"
    model = DeviceModel(PSY.GenericBattery, PSI.BookKeeping)
    op_model = OperationModel(TestOptModel, DCPPowerModel, c_sys5)
    @test_logs (:warn, warn_message) construct_device!(op_model, :Storage, model)
    op_model = OperationModel(TestOptModel, DCPPowerModel, c_sys14)
    @test_logs (:warn, warn_message) construct_device!(op_model, :Storage, model)
end

@testset "Storage Basic Storage With DC - PF" begin
    model = DeviceModel(PSY.GenericBattery, PSI.BookKeeping)
    op_model = OperationModel(TestOptModel, DCPPowerModel, c_sys5_bat)
    construct_device!(op_model, :Storage, model)
    moi_tests(op_model, false, 72, 0, 72, 72, 24, false)
    psi_checkobjfun_test(op_model, GAEVF)
end

@testset "Storage Basic Storage With AC - PF" begin
    model = DeviceModel(PSY.GenericBattery, PSI.BookKeeping)
    op_model = OperationModel(TestOptModel, ACPPowerModel, c_sys5_bat)
    construct_device!(op_model, :Storage, model)
    moi_tests(op_model, false, 96, 0, 96, 96, 24, false)
    psi_checkobjfun_test(op_model, GAEVF)
end

@testset "Storage with Reservation DC - PF" begin
    model = DeviceModel(PSY.GenericBattery, PSI.BookKeepingwReservation)
    op_model = OperationModel(TestOptModel, DCPPowerModel, c_sys5_bat)
    construct_device!(op_model, :Storage, model)
    moi_tests(op_model, false, 96, 0, 72, 72, 24, true)
    psi_checkobjfun_test(op_model, GAEVF)
end

@testset "Storage with Reservation With AC - PF" begin
    model = DeviceModel(PSY.GenericBattery, PSI.BookKeepingwReservation)
    op_model = OperationModel(TestOptModel, ACPPowerModel, c_sys5_bat)
    construct_device!(op_model, :Storage, model)
    moi_tests(op_model, false, 120, 0, 96, 96, 24, true)
    psi_checkobjfun_test(op_model, GAEVF)
end
