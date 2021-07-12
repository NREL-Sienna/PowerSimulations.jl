@testset "Load data misspecification" begin
    device_model = DeviceModel(InterruptibleLoad, DispatchablePowerLoad)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    warn_message = "The data doesn't include devices of type InterruptibleLoad, consider changing the device models"
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        model,
        device_model,
    )
    device_model = DeviceModel(PowerLoad, DispatchablePowerLoad)
    warn_message = "The Formulation DispatchablePowerLoad only applies to FormulationControllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad"
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        model,
        device_model,
    )
end

@testset "StaticPowerLoad" begin
    models = [StaticPowerLoad, DispatchablePowerLoad, InterruptiblePowerLoad]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [DCPPowerModel, ACPPowerModel]
    for m in models, n in networks
        device_model = DeviceModel(PowerLoad, m)
        model = DecisionModel(MockOperationProblem, n, c_sys5_il)
        mock_construct_device!(model, device_model)
        moi_tests(model, false, 0, 0, 0, 0, 0, false)
        psi_checkobjfun_test(model, GAEVF)
    end
end

@testset "DispatchablePowerLoad DC- PF" begin
    models = [DispatchablePowerLoad]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [DCPPowerModel]
    for m in models, n in networks
        device_model = DeviceModel(InterruptibleLoad, m)
        model = DecisionModel(MockOperationProblem, n, c_sys5_il)
        mock_construct_device!(model, device_model)
        moi_tests(model, false, 24, 0, 24, 0, 0, false)
        psi_checkobjfun_test(model, GAEVF)
    end
end

@testset "DispatchablePowerLoad AC- PF" begin
    models = [DispatchablePowerLoad]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [ACPPowerModel]
    for m in models, n in networks
        device_model = DeviceModel(InterruptibleLoad, m)
        model = DecisionModel(MockOperationProblem, n, c_sys5_il)
        mock_construct_device!(model, device_model)
        moi_tests(model, false, 48, 0, 24, 0, 24, false)
        psi_checkobjfun_test(model, GAEVF)
    end
end

@testset "InterruptiblePowerLoad DC- PF" begin
    models = [InterruptiblePowerLoad]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [DCPPowerModel]
    for m in models, n in networks
        device_model = DeviceModel(InterruptibleLoad, m)
        model = DecisionModel(MockOperationProblem, n, c_sys5_il)
        mock_construct_device!(model, device_model)
        moi_tests(model, false, 48, 0, 24, 0, 0, true)
        psi_checkobjfun_test(model, GAEVF)
    end
end

@testset "InterruptiblePowerLoad AC- PF" begin
    models = [InterruptiblePowerLoad]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [ACPPowerModel]
    for m in models, n in networks
        device_model = DeviceModel(InterruptibleLoad, m)
        model = DecisionModel(MockOperationProblem, n, c_sys5_il)
        mock_construct_device!(model, device_model)
        moi_tests(model, false, 72, 0, 24, 0, 24, true)
        psi_checkobjfun_test(model, GAEVF)
    end
end
