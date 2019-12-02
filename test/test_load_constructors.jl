@testset "Load data misspecification" begin
    model = DeviceModel(InterruptibleLoad, DispatchablePowerLoad)
    warn_message = "The data doesn't include devices of type InterruptibleLoad, consider changing the device models"
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5)
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Load, model);
    model = DeviceModel(PowerLoad, DispatchablePowerLoad)
    warn_message = "The Formulation DispatchablePowerLoad only applies to FormulationControllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad"
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5)
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Load, model);
end

@testset "StaticPowerLoad" begin
    models = [StaticPowerLoad, DispatchablePowerLoad, InterruptiblePowerLoad]
    networks = [DCPPowerModel, ACPPowerModel]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PowerLoad, m)
        op_problem = OperationsProblem(TestOpProblem, n, c_sys5_il; use_parameters = p)
        construct_device!(op_problem, :Load, model);
        moi_tests(op_problem, p, 0, 0, 0, 0, 0, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "DispatchablePowerLoad DC- PF" begin
    models = [DispatchablePowerLoad]
    networks = [DCPPowerModel]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(InterruptibleLoad, m)
        op_problem = OperationsProblem(TestOpProblem, n, c_sys5_il; use_parameters = p)
        construct_device!(op_problem, :Load, model);
        moi_tests(op_problem, p, 24, 0, 24, 0, 0, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "DispatchablePowerLoad AC- PF" begin
    models = [DispatchablePowerLoad, ]
    networks = [ACPPowerModel]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(InterruptibleLoad, m)
        op_problem = OperationsProblem(TestOpProblem, n, c_sys5_il; use_parameters = p)
        construct_device!(op_problem, :Load, model);
        moi_tests(op_problem, p, 48, 0, 24, 0, 24, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "InterruptiblePowerLoad DC- PF" begin
    models = [InterruptiblePowerLoad]
    networks = [DCPPowerModel]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(InterruptibleLoad, m)
        op_problem = OperationsProblem(TestOpProblem, n, c_sys5_il; use_parameters = p)
        construct_device!(op_problem, :Load, model);
        moi_tests(op_problem, p, 48, 0, p*48 + !p*24, 0, 0, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "InterruptiblePowerLoad AC- PF" begin
    models = [InterruptiblePowerLoad]
    networks = [ACPPowerModel]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(InterruptibleLoad, m)
        op_problem = OperationsProblem(TestOpProblem, n, c_sys5_il; use_parameters = p)
        construct_device!(op_problem, :Load, model);
        moi_tests(op_problem, p, 72, 0, p*48 + !p*24, 0, 24, true)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end
