@testset "Test Reserves from Thermal Dispatch" begin
    template = get_thermal_dispatch_template_network(CopperPlatePowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_service_model!(template, ServiceModel(VariableReserve{ReserveDown}, RangeReserve))
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    for p in [true, false]
        op_problem = DecisionProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 648, 0, 120, 216, 72, false)
        reserve_variables = [
            :ActivePowerReserveVariable_VariableReserve_ReserveUp_Reserve1
            :ActivePowerReserveVariable_ReserveDemandCurve_ReserveUp_ORDC1
            :ActivePowerReserveVariable_VariableReserve_ReserveDown_Reserve2
            :ActivePowerReserveVariable_VariableReserve_ReserveUp_Reserve11
        ]
        for (k, var_array) in op_problem.internal.container.variables
            if PSI.encode_key(k) in reserve_variables
                for var in var_array
                    @test JuMP.has_lower_bound(var)
                    @test JuMP.lower_bound(var) == 0.0
                end
            end
        end
    end
end

@testset "Test Ramp Reserves from Thermal Dispatch" begin
    template = get_thermal_dispatch_template_network(CopperPlatePowerModel)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RampReserve))
    set_service_model!(template, ServiceModel(VariableReserve{ReserveDown}, RampReserve))

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    for p in [true, false]
        op_problem = DecisionProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 384, 0, 336, 192, 24, false)
        reserve_variables = [
            :ActivePowerReserveVariable_VariableReserve_ReserveDown_Reserve2,
            :ActivePowerReserveVariable_VariableReserve_ReserveUp_Reserve1,
            :ActivePowerReserveVariable_VariableReserve_ReserveUp_Reserve11,
        ]
        for (k, var_array) in op_problem.internal.container.variables
            if PSI.encode_key(k) in reserve_variables
                for var in var_array
                    @test JuMP.has_lower_bound(var)
                    @test JuMP.lower_bound(var) == 0.0
                end
            end
        end
    end
end

@testset "Test Reserves from Thermal Standard UC" begin
    template = get_thermal_standard_uc_template()
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_service_model!(template, ServiceModel(VariableReserve{ReserveDown}, RangeReserve))
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
    )
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)

    for p in [true, false]
        op_problem = DecisionProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 1008, 0, 480, 216, 192, true)
    end
end

@testset "Test Upwards Reserves from Renewable Dispatch" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
    )

    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re"; add_reserves = true)
    for p in [true, false]
        op_problem = DecisionProblem(template, c_sys5_re; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 360, 0, 72, 48, 72, false)
    end
end

@testset "Test Reserves from Storage" begin
    template = get_thermal_dispatch_template_network(CopperPlatePowerModel)
    set_device_model!(template, GenericBattery, BookKeeping)
    set_device_model!(template, RenewableDispatch, FixedOutput)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_service_model!(template, ServiceModel(VariableReserve{ReserveDown}, RangeReserve))
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
    )

    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat"; add_reserves = true)
    for p in [true, false]
        op_problem = DecisionProblem(template, c_sys5_bat; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 408, 0, 192, 264, 96, false)
    end
end

@testset "Test Reserves from Hydro" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchRunOfRiver)
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_service_model!(template, ServiceModel(VariableReserve{ReserveDown}, RangeReserve))
    set_service_model!(
        template,
        ServiceModel(ReserveDemandCurve{ReserveUp}, StepwiseCostReserve),
    )

    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd"; add_reserves = true)
    for p in [true, false]
        op_problem = DecisionProblem(template, c_sys5_hyd; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 240, 0, 24, 96, 72, false)
    end
end

@testset "Test Reserves from with slack variables" begin
    template = get_thermal_dispatch_template_network()
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_service_model!(template, ServiceModel(VariableReserve{ReserveDown}, RangeReserve))

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    for p in [true, false]
        op_problem = DecisionProblem(
            template,
            c_sys5_uc;
            use_parameters = p,
            services_slack_variables = true,
            balance_slack_variables = true,
        )
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 504, 0, 120, 192, 24, false)
    end
end

@testset "Test AGC" begin
    c_sys5_reg = PSB.build_system(PSITestSystems, "c_sys5_reg")
    @test_throws ArgumentError template_agc_reserve_deployment(; dummy_arg = 0.0)

    template_agc = template_agc_reserve_deployment()
    agc_problem = DecisionProblem(AGCReserveDeployment, template_agc, c_sys5_reg)
    @test build!(agc_problem; output_dir = mktempdir(cleanup = true)) ==
          PSI.BuildStatus.BUILT
    # These values might change as the AGC model is refined
    moi_tests(agc_problem, false, 720, 0, 480, 0, 384, false)
end

@testset "Test GroupReserve from Thermal Dispatch" begin
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
        op_problem = DecisionProblem(template, c_sys5_uc; use_parameters = p)
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        moi_tests(op_problem, p, 648, 0, 120, 240, 72, false)
    end
end

# TODO: Test is broken
#=
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

    op_problem = DecisionProblem(template, c_sys5_uc; use_parameters = false)
    @test_logs(
        (:error, r"is not stored"),
        match_mode = :any,
        @test_throws InfrastructureSystems.InvalidValue build!(op_problem; output_dir = mktempdir(cleanup = true))
    )
end
=#

@testset "Test StaticReserve" begin
    template = get_thermal_dispatch_template_network()
    set_service_model!(template, ServiceModel(StaticReserve{ReserveUp}, RangeReserve))

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    static_reserve = StaticReserve{ReserveUp}("Reserve3", true, 30, 100)
    add_service!(c_sys5_uc, static_reserve, get_components(ThermalGen, c_sys5_uc))
    op_problem = DecisionProblem(template, c_sys5_uc)
    @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
          PSI.BuildStatus.BUILT
    @test typeof(op_problem) <: DecisionProblem
end
