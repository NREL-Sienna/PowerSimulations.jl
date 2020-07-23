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

@testset "Test AGC" begin
    # Temporary creation of system here until world of age problem is resolved
    nodes = nodes5()

    c_sys5_reg = System(
        nodes,
        thermal_generators5(nodes),
        loads5(nodes),
        branches5(nodes),
        nothing,
        100.0,
        nothing,
        nothing,
    )

    area = Area("1")
    add_component!(c_sys5_reg, area)
    [set_area!(b, area) for b in get_components(Bus, c_sys5_reg)]
    AGC_service = PSY.AGC(
        name = "AGC_Area1",
        available = true,
        bias = 739.0,
        K_p = 2.5,
        K_i = 0.1,
        K_d = 0.0,
        delta_t = 4,
        area = first(get_components(Area, c_sys5_reg)),
    )
    add_component!(c_sys5_reg, AGC_service)
    for t in 1:2
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_reg))
            add_forecast!(
                c_sys5_reg,
                l,
                Deterministic("get_max_active_power", load_timeseries_DA[t][ix]),
            )
        end
        for (_, l) in enumerate(get_components(ThermalStandard, c_sys5_reg))
            add_forecast!(
                c_sys5_reg,
                l,
                Deterministic("get_max_active_power", load_timeseries_DA[t][1]),
            )
        end
    end

    for g in get_components(Generator, c_sys5_reg)
        droop = isa(g, ThermalStandard) ? 0.04 * PSY.get_base_power(g) :
            0.05 * PSY.get_base_power(g)
        p_factor = (up = 1.0, dn = 1.0)
        t = RegulationDevice(g, participation_factor = p_factor, droop = droop)
        add_component!(c_sys5_reg, t)
        add_service!(t, AGC_service)
        @assert has_forecasts(t)
    end
    # End of the system creation code.
    devices = Dict(
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
        :Regulation_thermal =>
            DeviceModel(RegulationDevice{ThermalStandard}, DeviceLimitedRegulation),
    )
    services = Dict(:AGC => ServiceModel(AGC, PIDSmoothACE))

    @test_throws ArgumentError template_agc_reserve_deployment(devices = devices)

    template_agc = template_agc_reserve_deployment()
    agc_problem = OperationsProblem(AGCReserveDeployment, template_agc, c_sys5_reg)
    # These values might change as the AGC model is refined
    moi_tests(agc_problem, false, 720, 0, 480, 0, 384, false)
end
