@testset "Test Reserves from Thermal Dispatch" begin
    template = get_thermal_dispatch_template_network(CopperPlatePowerModel)
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve1"),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve11"),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveDown}, RangeReserve, "Reserve2"),
    )
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve, "ORDC1"),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves=true)
    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(model, false, 648, 0, 120, 216, 72, false)
    reserve_variables = [
        :ActivePowerReserveVariable__VariableReserve_ReserveUp_Reserve1
        :ActivePowerReserveVariable__ReserveDemandCurve_ReserveUp_ORDC1
        :ActivePowerReserveVariable__VariableReserve_ReserveDown_Reserve2
        :ActivePowerReserveVariable__VariableReserve_ReserveUp_Reserve11
    ]
    for (k, var_array) in model.internal.container.variables
        if PSI.encode_key(k) in reserve_variables
            for var in var_array
                @test JuMP.has_lower_bound(var)
                @test JuMP.lower_bound(var) == 0.0
            end
        end
    end
end

@testset "Test Ramp Reserves from Thermal Dispatch" begin
    template = get_thermal_dispatch_template_network(CopperPlatePowerModel)
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RampReserve, "Reserve1"),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RampReserve, "Reserve11"),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveDown}, RampReserve, "Reserve2"),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves=true)
    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(model, false, 384, 0, 336, 192, 24, false)
    reserve_variables = [
        :ActivePowerReserveVariable__VariableReserve_ReserveDown_Reserve2,
        :ActivePowerReserveVariable__VariableReserve_ReserveUp_Reserve1,
        :ActivePowerReserveVariable__VariableReserve_ReserveUp_Reserve11,
    ]
    for (k, var_array) in model.internal.container.variables
        if PSI.encode_key(k) in reserve_variables
            for var in var_array
                @test JuMP.has_lower_bound(var)
                @test JuMP.lower_bound(var) == 0.0
            end
        end
    end
end

@testset "Test Reserves from Thermal Standard UC" begin
    template = get_thermal_standard_uc_template()
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve1"),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve11"),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveDown}, RangeReserve, "Reserve2"),
    )
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve, "ORDC1"),
    )
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves=true)

    model = DecisionModel(template, c_sys5_uc; optimizer=cbc_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(model, false, 1008, 0, 480, 216, 192, true)
end

@testset "Test Reserves from Thermal Standard UC with NonSpinningReserve" begin
    template = get_thermal_standard_uc_template()
    set_device_model!(
        template,
        DeviceModel(ThermalMultiStart, ThermalStandardUnitCommitment),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserveNonSpinning, NonSpinningReserve, "NonSpinningReserve"),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc_non_spin"; add_reserves=true)
    model = DecisionModel(template, c_sys5_uc; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(model, false, 1032, 0, 888, 192, 288, true)
end

@testset "Test Upwards Reserves from Renewable Dispatch" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve3"),
    )
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve, "ORDC1"),
    )

    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re"; add_reserves=true)
    model = DecisionModel(template, c_sys5_re)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(model, false, 360, 0, 72, 48, 72, false)
end

@testset "Test Reserves from Storage" begin
    template = get_thermal_dispatch_template_network(CopperPlatePowerModel)
    set_device_model!(template, DeviceModel(GenericBattery, BatteryAncillaryServices))
    set_device_model!(template, RenewableDispatch, FixedOutput)
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve3"),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveDown}, RangeReserve, "Reserve4"),
    )
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve, "ORDC1"),
    )

    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat"; add_reserves=true)
    model = DecisionModel(template, c_sys5_bat)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(model, false, 432, 0, 288, 264, 96, true)
end

@testset "Test Reserves from Hydro" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchRunOfRiver)
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve5"),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveDown}, RangeReserve, "Reserve6"),
    )
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve, "ORDC1"),
    )

    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd"; add_reserves=true)
    model = DecisionModel(template, c_sys5_hyd)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(model, false, 240, 0, 48, 96, 72, false)
end

@testset "Test Reserves from with slack variables" begin
    template = get_thermal_dispatch_template_network(
        NetworkModel(CopperPlatePowerModel; use_slacks=true),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve1"; use_slacks=true),
    )
    set_service_model!(
        template,
        ServiceModel(
            VariableReserve{ReserveUp},
            RangeReserve,
            "Reserve11";
            use_slacks=true,
        ),
    )
    set_service_model!(
        template,
        ServiceModel(
            VariableReserve{ReserveDown},
            RangeReserve,
            "Reserve2";
            use_slacks=true,
        ),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves=true)
    model = DecisionModel(template, c_sys5_uc;)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(model, false, 504, 0, 120, 192, 24, false)
end

@testset "Test AGC" begin
    c_sys5_reg = PSB.build_system(PSITestSystems, "c_sys5_reg")
    @test_throws ArgumentError template_agc_reserve_deployment(; dummy_arg=0.0)

    template_agc = template_agc_reserve_deployment()
    set_service_model!(template_agc, ServiceModel(PSY.AGC, PIDSmoothACE, "AGC_Area1"))
    agc_problem = DecisionModel(AGCReserveDeployment, template_agc, c_sys5_reg)
    @test build!(agc_problem; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    # These values might change as the AGC model is refined
    moi_tests(agc_problem, false, 696, 0, 480, 0, 384, false)
end

@testset "Test GroupReserve from Thermal Dispatch" begin
    template = get_thermal_dispatch_template_network()
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve1"),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve11"),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveDown}, RangeReserve, "Reserve2"),
    )
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve, "ORDC1"),
    )
    set_service_model!(
        template,
        ServiceModel(StaticReserveGroup{ReserveDown}, GroupReserve, "init"),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves=true)
    services = get_components(Service, c_sys5_uc)
    contributing_services = Vector{Service}()
    for service in services
        if !(typeof(service) <: PSY.ReserveDemandCurve)
            push!(contributing_services, service)
        end
    end
    groupservice = StaticReserveGroup{ReserveDown}(;
        name="init",
        available=true,
        requirement=0.0,
        ext=Dict{String, Any}(),
    )
    add_service!(c_sys5_uc, groupservice, contributing_services)

    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(model, false, 648, 0, 120, 240, 72, false)
end

@testset "Test GroupReserve Errors" begin
    template = get_thermal_dispatch_template_network()
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_service_model!(template, ServiceModel(VariableReserve{ReserveDown}, RangeReserve))
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
    )
    set_service_model!(
        template,
        ServiceModel(StaticReserveGroup{ReserveDown}, GroupReserve),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves=true)
    services = get_components(Service, c_sys5_uc)
    contributing_services = Vector{Service}()
    for service in services
        if !(typeof(service) <: PSY.ReserveDemandCurve)
            push!(contributing_services, service)
        end
    end
    groupservice = StaticReserveGroup{ReserveDown}(;
        name="init",
        available=true,
        requirement=0.0,
        ext=Dict{String, Any}(),
    )
    add_service!(c_sys5_uc, groupservice, contributing_services)

    off_service = VariableReserve{ReserveUp}("Reserveoff", true, 0.6, 10)
    push!(groupservice.contributing_services, off_service)

    model = DecisionModel(template, c_sys5_uc)
    @test build!(
        model;
        output_dir=mktempdir(cleanup=true),
        console_level=Logging.AboveMaxLevel,
    ) == BuildStatus.FAILED
end

@testset "Test StaticReserve" begin
    template = get_thermal_dispatch_template_network()
    set_service_model!(
        template,
        ServiceModel(StaticReserve{ReserveUp}, RangeReserve, "Reserve3"),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    static_reserve = StaticReserve{ReserveUp}("Reserve3", true, 30, 100)
    add_service!(c_sys5_uc, static_reserve, get_components(ThermalGen, c_sys5_uc))
    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    @test typeof(model) <: DecisionModel{<:PSI.DecisionProblem}
end

@testset "Test Reserves with Feedforwards" begin
    template = get_thermal_dispatch_template_network()
    service_model = ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve1")
    ff_lb = LowerBoundFeedforward(
        component_type=VariableReserve{ReserveUp},
        source=ActivePowerReserveVariable,
        affected_values=[ActivePowerReserveVariable],
        meta="Reserve1",
    )
    PSI.attach_feedforward!(service_model, ff_lb)

    set_service_model!(template, service_model)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves=true)
    model = DecisionModel(template, c_sys5_uc; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    moi_tests(model, false, 240, 0, 120, 264, 24, false)
end
