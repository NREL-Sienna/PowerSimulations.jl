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
