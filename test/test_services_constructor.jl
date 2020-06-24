@testset "Test Reserves from Thermal Dispatch" begin
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{Symbol, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(
        :Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
        :DownReserve => ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
        :ORDC => ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
    )
    model_template = OperationsProblemTemplate(
        CopperPlatePowerModel,
        devices,
        branches,
        services_template,
    )
    c_sys5_uc = build_system("c_sys5_uc"; add_reserves = true)
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, model_template, c_sys5_uc; use_parameters = p)
        moi_tests(op_problem, p, 648, 0, 120, 216, 72, false)
    end
end

@testset "Test Reserves from Thermal Standard UC" begin
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{Symbol, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(
        :UpReserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
        :DownReserve => ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
        :ORDC => ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
    )
    model_template = OperationsProblemTemplate(
        CopperPlatePowerModel,
        devices,
        branches,
        services_template,
    )
    c_sys5_uc = build_system("c_sys5_uc"; add_reserves = true)
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, model_template, c_sys5_uc; use_parameters = p)
        moi_tests(op_problem, p, 1008, 0, 240, 216, 192, true)
    end
end

@testset "Test Upwards Reserves from Renewable Dispatch" begin
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(RenewableDispatch, RenewableFullDispatch),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{Symbol, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(
        :Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
        :ORDC => ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
    )
    model_template = OperationsProblemTemplate(
        CopperPlatePowerModel,
        devices,
        branches,
        services_template,
    )
    c_sys5_re = build_system("c_sys5_re"; add_reserves = true)
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, model_template, c_sys5_re; use_parameters = p)
        moi_tests(op_problem, p, 360, 0, 72, 48, 72, false)
    end
end

@testset "Test Reserves from Storage" begin
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
        :Storage => DeviceModel(GenericBattery, BookKeeping),
        # Added here to test it doesn't add reserve variables
        :Ren => DeviceModel(RenewableDispatch, FixedOutput),
    )
    branches = Dict{Symbol, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(
        :Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
        :DownReserve => ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
        :ORDC => ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
    )
    model_template = OperationsProblemTemplate(
        CopperPlatePowerModel,
        devices,
        branches,
        services_template,
    )
    c_sys5_bat = build_system("c_sys5_bat"; add_reserves = true)
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, model_template, c_sys5_bat; use_parameters = p)
        moi_tests(op_problem, p, 408, 0, 192, 264, 96, false)
    end
end

@testset "Test Reserves from Hydro" begin
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{Symbol, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(
        :Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
        :DownReserve => ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
        :ORDC => ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
    )
    model_template = OperationsProblemTemplate(
        CopperPlatePowerModel,
        devices,
        branches,
        services_template,
    )
    c_sys5_hyd = build_system("c_sys5_hyd"; add_reserves = true)
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, model_template, c_sys5_hyd; use_parameters = p)
        moi_tests(op_problem, p, 240, 0, 24, 96, 72, false)
    end
end

@testset "Test Reserves from with slack variables" begin
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{Symbol, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(
        :Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
        :DownReserve => ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
    )
    model_template = OperationsProblemTemplate(
        CopperPlatePowerModel,
        devices,
        branches,
        services_template,
    )
    c_sys5_uc = build_system("c_sys5_uc"; add_reserves = true)
    for p in [true, false]
        op_problem = OperationsProblem(
            TestOpProblem,
            model_template,
            c_sys5_uc;
            use_parameters = p,
            services_slack_variables = true,
            balance_slack_variables = true,
        )
        moi_tests(op_problem, p, 504, 0, 120, 192, 24, false)
    end
end
