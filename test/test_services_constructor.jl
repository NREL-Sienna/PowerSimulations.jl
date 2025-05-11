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

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 624, 0, 216, 216, 48, false)
    reserve_variables = [
        :ActivePowerReserveVariable__VariableReserve__ReserveUp__Reserve1
        :ActivePowerReserveVariable__ReserveDemandCurve__ReserveUp__ORDC1
        :ActivePowerReserveVariable__VariableReserve__ReserveDown__Reserve2
        :ActivePowerReserveVariable__VariableReserve__ReserveUp__Reserve11
    ]
    found_vars = 0
    for (k, var_array) in PSI.get_optimization_container(model).variables
        if IS.Optimization.encode_key(k) in reserve_variables
            for var in var_array
                @test JuMP.has_lower_bound(var)
                @test JuMP.lower_bound(var) == 0.0
            end
            found_vars += 1
        end
    end
    @test found_vars == 4
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

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 384, 0, 336, 192, 24, false)
    reserve_variables = [
        :ActivePowerReserveVariable__VariableReserve_ReserveDown_Reserve2,
        :ActivePowerReserveVariable__VariableReserve_ReserveUp_Reserve1,
        :ActivePowerReserveVariable__VariableReserve_ReserveUp_Reserve11,
    ]
    for (k, var_array) in PSI.get_optimization_container(model).variables
        if IS.Optimization.encode_key(k) in reserve_variables
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
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)

    model = DecisionModel(template, c_sys5_uc; optimizer = HiGHS_optimizer)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 984, 0, 576, 216, 168, true)
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

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc_non_spin"; add_reserves = true)
    model = DecisionModel(template, c_sys5_uc; optimizer = HiGHS_optimizer)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 1032, 0, 888, 192, 288, true)
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

    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re"; add_reserves = true)
    model = DecisionModel(template, c_sys5_re)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 336, 0, 168, 120, 48, false)
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

    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd"; add_reserves = true)
    model = DecisionModel(template, c_sys5_hyd)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 216, 0, 144, 96, 48, false)
end

@testset "Test Reserves from with slack variables" begin
    template = get_thermal_dispatch_template_network(
        NetworkModel(CopperPlatePowerModel; use_slacks = true),
    )
    set_service_model!(
        template,
        ServiceModel(
            VariableReserve{ReserveUp},
            RangeReserve,
            "Reserve1";
            use_slacks = true,
        ),
    )
    set_service_model!(
        template,
        ServiceModel(
            VariableReserve{ReserveUp},
            RangeReserve,
            "Reserve11";
            use_slacks = true,
        ),
    )
    set_service_model!(
        template,
        ServiceModel(
            VariableReserve{ReserveDown},
            RangeReserve,
            "Reserve2";
            use_slacks = true,
        ),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    model = DecisionModel(template, c_sys5_uc;)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 504, 0, 120, 192, 24, false)
end

#=
@testset "Test AGC" begin
    c_sys5_reg = PSB.build_system(PSITestSystems, "c_sys5_reg")
    @test_throws ArgumentError template_agc_reserve_deployment(; dummy_arg = 0.0)

    template_agc = template_agc_reserve_deployment()
    set_service_model!(template_agc, ServiceModel(PSY.AGC, PIDSmoothACE, "AGC_Area1"))
    agc_problem = DecisionModel(AGCReserveDeployment, template_agc, c_sys5_reg)
    @test build!(agc_problem; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    # These values might change as the AGC model is refined
    moi_tests(agc_problem, 696, 0, 480, 0, 384, false)
end
=#

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
        ServiceModel(ConstantReserveGroup{ReserveDown}, GroupReserve, "init"),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    services = get_components(Service, c_sys5_uc)
    contributing_services = Vector{Service}()
    for service in services
        if !(typeof(service) <: PSY.ReserveDemandCurve)
            push!(contributing_services, service)
        end
    end
    groupservice = ConstantReserveGroup{ReserveDown}(;
        name = "init",
        available = true,
        requirement = 0.0,
        ext = Dict{String, Any}(),
    )
    add_service!(c_sys5_uc, groupservice, contributing_services)

    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 624, 0, 216, 240, 48, false)
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
        ServiceModel(ConstantReserveGroup{ReserveDown}, GroupReserve),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    services = get_components(Service, c_sys5_uc)
    contributing_services = Vector{Service}()
    for service in services
        if !(typeof(service) <: PSY.ReserveDemandCurve)
            push!(contributing_services, service)
        end
    end
    groupservice = ConstantReserveGroup{ReserveDown}(;
        name = "init",
        available = true,
        requirement = 0.0,
        ext = Dict{String, Any}(),
    )
    add_service!(c_sys5_uc, groupservice, contributing_services)

    off_service = VariableReserve{ReserveUp}("Reserveoff", true, 0.6, 10)
    push!(groupservice.contributing_services, off_service)

    model = DecisionModel(template, c_sys5_uc)
    @test build!(
        model;
        output_dir = mktempdir(; cleanup = true),
        console_level = Logging.AboveMaxLevel,
    ) == PSI.ModelBuildStatus.FAILED
end

@testset "Test ConstantReserve" begin
    template = get_thermal_dispatch_template_network()
    set_service_model!(
        template,
        ServiceModel(ConstantReserve{ReserveUp}, RangeReserve, "Reserve3"),
    )

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    static_reserve = ConstantReserve{ReserveUp}("Reserve3", true, 30, 100)
    add_service!(c_sys5_uc, static_reserve, get_components(ThermalGen, c_sys5_uc))
    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    @test typeof(model) <: DecisionModel{<:PSI.DecisionProblem}
end

@testset "Test Reserves with Feedforwards" begin
    template = get_thermal_dispatch_template_network()
    service_model = ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve1")
    ff_lb = LowerBoundFeedforward(;
        component_type = VariableReserve{ReserveUp},
        source = ActivePowerReserveVariable,
        affected_values = [ActivePowerReserveVariable],
        meta = "Reserve1",
    )
    PSI.attach_feedforward!(service_model, ff_lb)

    set_service_model!(template, service_model)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    model = DecisionModel(template, c_sys5_uc; optimizer = HiGHS_optimizer)
    # set manually to test cases for simulation
    PSI.get_optimization_container(model).built_for_recurrent_solves = true
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 456, 0, 120, 264, 24, false)
end

@testset "Test Reserves with Participation factor limits" begin
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    for service in get_components(Reserve, c_sys5_uc)
        set_max_participation_factor!(service, 0.8)
    end

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

    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 624, 0, 480, 216, 48, false)
    reserve_variables = [
        :ActivePowerReserveVariable__VariableReserve__ReserveUp__Reserve1
        :ActivePowerReserveVariable__ReserveDemandCurve__ReserveUp__ORDC1
        :ActivePowerReserveVariable__VariableReserve__ReserveDown__Reserve2
        :ActivePowerReserveVariable__VariableReserve__ReserveUp__Reserve11
    ]
    found_vars = 0
    for (k, var_array) in PSI.get_optimization_container(model).variables
        if IS.Optimization.encode_key(k) in reserve_variables
            for var in var_array
                @test JuMP.has_lower_bound(var)
                @test JuMP.lower_bound(var) == 0.0
            end
            found_vars += 1
        end
    end
    @test found_vars == 4

    participation_constraints = [
        :ParticipationFractionConstraint__VariableReserve__ReserveUp__Reserve11,
        :ParticipationFractionConstraint__VariableReserve__ReserveDown__Reserve2,
    ]

    found_constraints = 0

    for (k, _) in PSI.get_optimization_container(model).constraints
        if IS.Optimization.encode_key(k) in participation_constraints
            found_constraints += 1
        end
    end

    @test found_constraints == 2
end

@testset "Test G-1 Security Constraints with Reserves" begin
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    network_model = NetworkModel(PTDFPowerModel; PTDF_matrix = PTDF(c_sys5_uc), LODF_matrix = LODF(c_sys5_uc))
    template = ProblemTemplate(network_model)
    # template = ProblemTemplate(NetworkModel(PTDFPowerModel; PTDF_matrix=PTDF(c_sys5_uc), LODF_matrix=LODF(c_sys5_uc)))
    set_device_model!(template, ThermalStandard, ThermalSecurityConstrainedUnitCommitmentWithReserves)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, Line, StaticBranch)
    # add service model that maps to the generator outages
    set_service_model!(
    template, 
    ServiceModel(
        VariableReserve{ReserveUp}, RangeReserve, "Reserve1";
            attributes=Dict(
                "contingencies" => ["Park City"],
            ),
        )
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveDown}, RangeReserve, "Reserve2"),
    )

    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Reserve11"),
    )
    model = DecisionModel(template, c_sys5_uc; optimizer = HiGHS_optimizer)
    transition_data_gl = GeometricDistributionForcedOutage(;
    mean_time_to_recovery = 20,
    outage_transition_probability = 0.9999,
    )

    # add single generator outage
    generator = get_component(ThermalStandard, c_sys5_uc, "Park City")
    add_supplemental_attribute!(c_sys5_uc, generator, transition_data_gl)

    #Set Rating B for all branches
    for branch in get_components(ACBranch, c_sys5_uc)
        if typeof(branch) == TwoTerminalGenericHVDCLine
            continue
        end
         set_rating_b!(branch, get_rating(branch) * 1.5)
    end

    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT

    # moi_tests(model, 1080, 0, 1104, 624, 336, true)
    post_contingency_variables = [
        :PostContingencyActivePowerReserveDeployedVariable__VariableReserve__ReserveUp__Reserve1,
        :PostContingencyActivePowerReserveDeployedVariable__VariableReserve__ReserveDown__Reserve2,
        :PostContingencyActivePowerReserveDeployedVariable__VariableReserve__ReserveUp__Reserve11,
    ]
    found_vars = 0
    for (k, var_array) in PSI.get_optimization_container(model).variables
        if IS.Optimization.encode_key(k) in post_contingency_variables
            for var in var_array
                @test JuMP.has_lower_bound(var)
                @test JuMP.lower_bound(var) == 0.0
            end
            found_vars += 1
        end
    end
    # only add the reserve variables for the reserve mapped to the generator outage
    @test found_vars == 1

    check_constraint_count(
        model,
        PostContingencyRateLimitConstraintWithReserves(),
        ACBranch;
        meta = "Reserve1_ub"
    )

    check_constraint_count(
        model,
        PostContingencyRateLimitConstraintWithReserves(),
        ACBranch;
        meta = "Reserve1_lb"
    )

    check_constraint_count(
        model,
        PostContingencyReserveDeploymentBalanceConstraint(),
        VariableReserve{ReserveUp};
        filter_func = (x -> PSY.get_name(x) == "Reserve1"),
        meta = "Reserve1"
    )

    post_contingency_deployment_constraints = [
        :PostContingencyReserveDeploymentLimitConstraint__VariableReserve__ReserveUp__Reserve1,
        :PostContingencyReserveDeploymentLimitConstraint__VariableReserve__ReserveDown__Reserve2,
        :PostContingencyReserveDeploymentLimitConstraint__VariableReserve__ReserveUp__Reserve11,
    ]

    found_constraints = 0
    for (k, _) in PSI.get_optimization_container(model).constraints
        if IS.Optimization.encode_key(k) in post_contingency_deployment_constraints
            found_constraints += 1
        end
    end
    @test found_constraints == 1

    solve!(model)
    psi_checksolve_test(model, [MOI.OPTIMAL], 386628.958, 1000.0)
    # check post contingency reserve deployment balance constraint
    reserve_deployed = PSI.get_variable(
        PSI.get_optimization_container(model), 
        PostContingencyActivePowerReserveDeployedVariable(), 
        VariableReserve{ReserveUp},
        "Reserve1"
    )
    max_power = PSY.get_max_active_power(generator)
    var_sum_t = sum(Array(PSI.jump_value.(reserve_deployed[:, "Park City", :])); dims = 1)
    @test all(p -> isapprox(p, max_power, atol = 1e-1), var_sum_t)

    # use dispatched power in the post contingency reserve deployment balance constraint
    set_service_model!(
        template,
        ServiceModel(
            VariableReserve{ReserveUp},
            RangeReserve,
            "Reserve1";
            attributes = Dict(
                "contingencies" => ["Park City"],
                "use_dispatched_power" => true,
            ),
        ),
    )
    model = DecisionModel(template, c_sys5_uc; optimizer = HiGHS_optimizer)

    build!(model; output_dir = mktempdir(; cleanup = true))
    solve!(model)
    reserve_deployed = PSI.get_variable(
        PSI.get_optimization_container(model), 
        PostContingencyActivePowerReserveDeployedVariable(), 
        VariableReserve{ReserveUp},
        "Reserve1"
    )

    active_power = PSI.get_variable(
        PSI.get_optimization_container(model), 
        ActivePowerVariable(),
        ThermalStandard,
    )
    active_power_t = PSI.jump_value.(active_power["Park City", :])

    var_sum_t = sum(Array(PSI.jump_value.(reserve_deployed[:, "Park City", :])); dims = 1)
    
    for t in 1:24
        @test isapprox(var_sum_t[t], active_power_t[t], atol = 1e-1)
    end

end

@testset "Test Transmission Interface" begin
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    interface = TransmissionInterface(;
        name = "west_east",
        available = true,
        active_power_flow_limits = (min = 0.0, max = 400.0),
    )
    interface_lines = [
        get_component(Line, c_sys5_uc, "1"),
        get_component(Line, c_sys5_uc, "2"),
        get_component(Line, c_sys5_uc, "6"),
    ]
    add_service!(c_sys5_uc, interface, interface_lines)

    template = get_thermal_dispatch_template_network(DCPPowerModel)
    set_service_model!(
        template,
        ServiceModel(TransmissionInterface, ConstantMaxInterfaceFlow; use_slacks = true),
    )

    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 432, 144, 288, 288, 288, false)

    template = get_thermal_dispatch_template_network(PTDFPowerModel)
    set_service_model!(
        template,
        ServiceModel(TransmissionInterface, ConstantMaxInterfaceFlow; use_slacks = true),
    )
    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 312, 0, 288, 288, 168, false)

    #= TODO: Fix this test
    template = get_thermal_dispatch_template_network(ACPPowerModel; use_slacks = true) where
    set_service_model!(
        template,
        ServiceModel(TransmissionInterface, ConstantMaxInterfaceFlow; use_slacks = true),
    )
    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(model, 312, 0, 288, 288, 168, false)
    =#
end

@testset "Test Transmission Interface with TimeSeries" begin
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    interface = TransmissionInterface(;
        name = "west_east",
        available = true,
        active_power_flow_limits = (min = 0.0, max = 400.0),
    )
    interface_lines = [
        get_component(Line, c_sys5_uc, "1"),
        get_component(Line, c_sys5_uc, "2"),
        get_component(Line, c_sys5_uc, "6"),
    ]
    add_service!(c_sys5_uc, interface, interface_lines)
    # Add TimeSeries Data
    data_minflow = Dict(
        DateTime("2024-01-01T00:00:00") => zeros(24),
        DateTime("2024-01-02T00:00:00") => zeros(24),
    )

    forecast_minflow = Deterministic(
        "min_active_power_flow_limit",
        data_minflow,
        Hour(1);
        scaling_factor_multiplier = get_min_active_power_flow_limit,
    )

    data_maxflow = Dict(
        DateTime("2024-01-01T00:00:00") => [
            0.9, 0.85, 0.95, 0.2, 0.15, 0.2,
            0.9, 0.85, 0.95, 0.2, 0.15, 0.2,
            0.9, 0.85, 0.95, 0.2, 0.5, 0.5,
            0.9, 0.85, 0.95, 0.2, 0.6, 0.6,
        ],
        DateTime("2024-01-02T00:00:00") => [
            0.9, 0.85, 0.95, 0.2, 0.15, 0.2,
            0.9, 0.85, 0.95, 0.2, 0.15, 0.2,
            0.9, 0.85, 0.95, 0.2, 0.5, 0.5,
            0.9, 0.85, 0.95, 0.2, 0.6, 0.6,
        ],
    )

    forecast_maxflow = Deterministic(
        "max_active_power_flow_limit",
        data_maxflow,
        Hour(1);
        scaling_factor_multiplier = get_max_active_power_flow_limit,
    )

    add_time_series!(c_sys5_uc, interface, forecast_minflow)
    add_time_series!(c_sys5_uc, interface, forecast_maxflow)

    template = get_thermal_dispatch_template_network(DCPPowerModel)
    set_service_model!(
        template,
        ServiceModel(TransmissionInterface, VariableMaxInterfaceFlow; use_slacks = true),
    )

    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 432, 144, 288, 288, 288, false)

    template = get_thermal_dispatch_template_network(PTDFPowerModel)
    set_service_model!(
        template,
        ServiceModel(TransmissionInterface, VariableMaxInterfaceFlow; use_slacks = true),
    )
    model = DecisionModel(template, c_sys5_uc)
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    moi_tests(model, 312, 0, 288, 288, 168, false)
end

@testset "Test Transmission Interface with Feedforwards" begin
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    interface = TransmissionInterface(;
        name = "west_east",
        available = true,
        active_power_flow_limits = (min = 0.0, max = 400.0),
    )
    interface_lines = [
        get_component(Line, c_sys5_uc, "1"),
        get_component(Line, c_sys5_uc, "2"),
        get_component(Line, c_sys5_uc, "6"),
    ]
    add_service!(c_sys5_uc, interface, interface_lines)
    c_sys5_uc2 = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    interface2 = TransmissionInterface(;
        name = "west_east",
        available = true,
        active_power_flow_limits = (min = 0.0, max = 400.0),
    )
    interface_lines2 = [
        get_component(Line, c_sys5_uc2, "1"),
        get_component(Line, c_sys5_uc2, "2"),
        get_component(Line, c_sys5_uc2, "6"),
    ]
    add_service!(c_sys5_uc2, interface2, interface_lines2)

    template = get_thermal_dispatch_template_network(DCPPowerModel)
    set_service_model!(
        template,
        ServiceModel(TransmissionInterface, ConstantMaxInterfaceFlow; use_slacks = true),
    )
    models = SimulationModels(;
        decision_models = [
            DecisionModel(template, c_sys5_uc; optimizer = HiGHS_optimizer, name = "Sys1"),
            DecisionModel(template, c_sys5_uc2; optimizer = HiGHS_optimizer, name = "Sys2"),
        ],
    )

    feedforward = Dict(
        "Sys2" => [
            FixValueFeedforward(;
                component_type = TransmissionInterface,
                source = PSI.FlowActivePowerVariable,
                affected_values = [PSI.FlowActivePowerVariable],
            ),
        ],
    )

    sequence = SimulationSequence(;
        models = models,
        ini_cond_chronology = InterProblemChronology(),
        feedforwards = feedforward,
    )

    sim = Simulation(;
        name = "interface-fail",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
    @test_throws ArgumentError build!(sim; console_level = Logging.AboveMaxLevel)
end
