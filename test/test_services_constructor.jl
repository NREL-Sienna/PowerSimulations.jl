@testset "Test Reserves from Thermal Dispatch" begin
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
        op_problem =
            OperationsProblem(TestOpProblem, model_template, c_sys5_uc; use_parameters = p)
        moi_tests(op_problem, p, 384, 0, 120, 192, 24, false)
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
        moi_tests(op_problem, p, 744, 0, 240, 192, 144, true)
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
        moi_tests(op_problem, p, 144, 0, 72, 24, 24, false)
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
        moi_tests(op_problem, p, 240, 0, 192, 240, 48, false)
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
        moi_tests(op_problem, p, 72, 0, 24, 72, 24, false)
    end
end
