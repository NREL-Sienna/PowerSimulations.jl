@testset "Load data misspecification" begin
    model = DeviceModel(PSY.InterruptibleLoad, PSI.DispatchablePowerLoad)
    warn_message = "The data doesn't devices of type InterruptibleLoad, consider changing the device models"
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5)
    @test_logs (:warn, warn_message) construct_device!(op_model, :Load, model);
    model = DeviceModel(PSY.PowerLoad, PSI.DispatchablePowerLoad)
    warn_message = "The Formulation DispatchablePowerLoad only applies to Controllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad"
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5)
    @test_logs (:warn, warn_message) construct_device!(op_model, :Load, model);
end

@testset "StaticPowerLoad" begin
    models = [PSI.StaticPowerLoad, PSI.DispatchablePowerLoad, PSI.InterruptiblePowerLoad]
    networks = [PM.DCPlosslessForm, PM.StandardACPForm]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PSY.PowerLoad, m)
        op_model = OperationModel(TestOptModel, n, c_sys5_il; parameters = p)
        construct_device!(op_model, :Load, model);
        moi_tests(op_model, p, 0, 0, 0, 0, 0, false)
        psi_checkobjfun_test(op_model, GAEVF)
    end
end

@testset "DispatchablePowerLoad DC- PF" begin
    models = [PSI.DispatchablePowerLoad]
    networks = [PM.DCPlosslessForm]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PSY.InterruptibleLoad, m)
        op_model = OperationModel(TestOptModel, n, c_sys5_il; parameters = p)
        construct_device!(op_model, :Load, model);
        moi_tests(op_model, p, 24, 0, 24, 0, 0, false)
        psi_checkobjfun_test(op_model, GAEVF)
    end
end

@testset "DispatchablePowerLoad AC- PF" begin
    models = [PSI.DispatchablePowerLoad, ]
    networks = [PM.StandardACPForm]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PSY.InterruptibleLoad, m)
        op_model = OperationModel(TestOptModel, n, c_sys5_il; parameters = p)
        construct_device!(op_model, :Load, model);
        moi_tests(op_model, p, 48, 0, 24, 0, 24, false)
        psi_checkobjfun_test(op_model, GAEVF)
    end
end

@testset "InterruptiblePowerLoad DC- PF" begin
    models = [PSI.InterruptiblePowerLoad]
    networks = [PM.DCPlosslessForm]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PSY.InterruptibleLoad, m)
        op_model = OperationModel(TestOptModel, n, c_sys5_il; parameters = p)
        construct_device!(op_model, :Load, model);
        moi_tests(op_model, p, 48, 0, p*48 + !p*24, 0, 0, true)
        psi_checkobjfun_test(op_model, GAEVF)
    end
end

@testset "InterruptiblePowerLoad AC- PF" begin
    models = [PSI.InterruptiblePowerLoad]
    networks = [PM.StandardACPForm]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PSY.InterruptibleLoad, m)
        op_model = OperationModel(TestOptModel, n, c_sys5_il; parameters = p)
        construct_device!(op_model, :Load, model);
        moi_tests(op_model, p, 72, 0, p*48 + !p*24, 0, 24, true)
        psi_checkobjfun_test(op_model, GAEVF)
    end
end
