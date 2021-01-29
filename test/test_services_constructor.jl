@testset "Test Reserves from Thermal Dispatch" begin
    devices = Dict{String, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{String, DeviceModel}()
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
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            model_template,
            c_sys5_uc;
            use_parameters = p,
        )
        moi_tests(op_problem, p, 648, 0, 120, 216, 72, false)
        symbols = [
            :Reserve1__VariableReserve_ReserveUp,
            :Reserve11__VariableReserve_ReserveUp,
            :Reserve2__VariableReserve_ReserveDown,
            :ORDC1__ReserveDemandCurve_ReserveUp,
        ]
        for sym in symbols
            for v in op_problem.optimization_container.variables[sym]
                @test JuMP.has_lower_bound(v)
                @test JuMP.lower_bound(v) == 0.0
            end
        end
    end
end

@testset "Test Reserves from Thermal Standard UC" begin
    devices = Dict{String, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{String, DeviceModel}()
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
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            model_template,
            c_sys5_uc;
            use_parameters = p,
        )
        moi_tests(op_problem, p, 1008, 0, 240, 216, 192, true)
    end
end

@testset "Test Upwards Reserves from Renewable Dispatch" begin
    devices = Dict{String, DeviceModel}(
        :Generators => DeviceModel(RenewableDispatch, RenewableFullDispatch),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{String, DeviceModel}()
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
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re"; add_reserves = true)
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            model_template,
            c_sys5_re;
            use_parameters = p,
        )
        moi_tests(op_problem, p, 360, 0, 72, 48, 72, false)
    end
end

@testset "Test Reserves from Storage" begin
    devices = Dict{String, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
        :Storage => DeviceModel(GenericBattery, BookKeeping),
        # Added here to test it doesn't add reserve variables
        :Ren => DeviceModel(RenewableDispatch, FixedOutput),
    )
    branches = Dict{String, DeviceModel}()
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
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat"; add_reserves = true)
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            model_template,
            c_sys5_bat;
            use_parameters = p,
        )
        moi_tests(op_problem, p, 408, 0, 192, 264, 96, false)
    end
end

@testset "Test Reserves from Hydro" begin
    devices = Dict{String, DeviceModel}(
        :Generators => DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{String, DeviceModel}()
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
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd"; add_reserves = true)
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            model_template,
            c_sys5_hyd;
            use_parameters = p,
        )
        moi_tests(op_problem, p, 240, 0, 24, 96, 72, false)
    end
end

@testset "Test Reserves from with slack variables" begin
    devices = Dict{String, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{String, DeviceModel}()
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
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
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
    c_sys5_reg = PSB.build_system(PSITestSystems, "c_sys5_reg")
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

@testset "Test GroupReserve from Thermal Dispatch" begin
    devices = Dict{String, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{String, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(
        :Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
        :DownReserve => ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
        :ORDC => ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
        :GroupReserve => ServiceModel(StaticReserveGroup{ReserveDown}, GroupReserve),
    )
    model_template = OperationsProblemTemplate(
        CopperPlatePowerModel,
        devices,
        branches,
        services_template,
    )
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    services = get_components(Service, c_sys5_uc)
    contributing_services = Vector{Service}()
    for service in services
        if !(typeof(service) <: PSY.ReserveDemandCurve)
            push!(contributing_services, service)
        end
    end
    groupservice = StaticReserveGroup{ReserveDown}(;
        name = "init",
        available = true,
        requirement = 0.0,
        ext = Dict{String, Any}(),
    )
    add_service!(c_sys5_uc, groupservice, contributing_services)

    for p in [true, false]
        op_problem = OperationsProblem(
            MockOperationProblem,
            model_template,
            c_sys5_uc;
            use_parameters = p,
        )
        moi_tests(op_problem, p, 648, 0, 120, 240, 72, false)
    end
end

@testset "Test GroupReserve Errors" begin
    devices = Dict{String, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{String, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(
        :Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
        :DownReserve => ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
        :ORDC => ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
        :GroupReserve => ServiceModel(StaticReserveGroup{ReserveDown}, GroupReserve),
    )
    model_template = OperationsProblemTemplate(
        CopperPlatePowerModel,
        devices,
        branches,
        services_template,
    )
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    services = get_components(Service, c_sys5_uc)
    contributing_services = Vector{Service}()
    for service in services
        if !(typeof(service) <: PSY.ReserveDemandCurve)
            push!(contributing_services, service)
        end
    end
    groupservice = StaticReserveGroup{ReserveDown}(;
        name = "init",
        available = true,
        requirement = 0.0,
        ext = Dict{String, Any}(),
    )
    add_service!(c_sys5_uc, groupservice, contributing_services)

    off_service = VariableReserve{ReserveUp}("Reserveoff", true, 0.6, 10)
    push!(groupservice.contributing_services, off_service)

    @test_logs(
        (:error, r"is not stored"),
        match_mode = :any,
        @test_throws InfrastructureSystems.InvalidValue op_problem = OperationsProblem(
            MockOperationProblem,
            model_template,
            c_sys5_uc;
            use_parameters = false,
        )
    )
end

@testset "Test StaticReserve" begin
    devices = Dict{String, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
        :Loads => DeviceModel(PowerLoad, PSI.StaticPowerLoad),
    )
    branches = Dict{String, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(
        :UpReserve => ServiceModel(StaticReserve{ReserveUp}, RangeReserve),
    )
    model_template = OperationsProblemTemplate(
        CopperPlatePowerModel,
        devices,
        branches,
        services_template,
    )
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    static_reserve = StaticReserve{ReserveUp}("Reserve3", true, 30, 100)
    add_service!(c_sys5_uc, static_reserve, get_components(ThermalGen, c_sys5_uc))
    op_problem = OperationsProblem(MockOperationProblem, model_template, c_sys5_uc)
    @test typeof(op_problem) <: OperationsProblem
end
