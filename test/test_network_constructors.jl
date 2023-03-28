# Note to devs. Use GLPK or Cbc for models with linear constraints and linear cost functions
# Use OSQP for models with quadratic cost function and linear constraints and ipopt otherwise
@testset "All PowerModels models construction" begin
    networks = [
        (PM.ACPPowerModel, fast_ipopt_optimizer),
        (PM.ACRPowerModel, fast_ipopt_optimizer),
        (PM.ACTPowerModel, fast_ipopt_optimizer),
        #(PM.IVRPowerModel, fast_ipopt_optimizer), #instantiate_ivp_expr_model not implemented
        (PM.DCPPowerModel, fast_ipopt_optimizer),
        (PM.DCMPPowerModel, fast_ipopt_optimizer),
        (PM.NFAPowerModel, fast_ipopt_optimizer),
        (PM.DCPLLPowerModel, fast_ipopt_optimizer),
        (PM.LPACCPowerModel, fast_ipopt_optimizer),
        (PM.SOCWRPowerModel, fast_ipopt_optimizer),
        (PM.SOCWRConicPowerModel, scs_solver),
        (PM.QCRMPowerModel, fast_ipopt_optimizer),
        (PM.QCLSPowerModel, fast_ipopt_optimizer),
        #(PM.SOCBFPowerModel, fast_ipopt_optimizer), # not implemented
        (PM.BFAPowerModel, fast_ipopt_optimizer),
        #(PM.SOCBFConicPowerModel, fast_ipopt_optimizer), # not implemented
        (PM.SDPWRMPowerModel, scs_solver),
        (PM.SparseSDPWRMPowerModel, scs_solver),
        (PTDFPowerModel, fast_ipopt_optimizer),
    ]
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    for (network, solver) in networks
        template = get_thermal_dispatch_template_network(
            NetworkModel(network; PTDF_matrix = PTDF(c_sys5)),
        )
        ps_model = DecisionModel(template, c_sys5; optimizer = solver)
        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT
        @test ps_model.internal.container.pm !== nothing
        # TODO: Change test
        # @test :nodal_balance_active in keys(ps_model.internal.container.expressions)
    end
end

@testset "Network Copper Plate" begin
    template = get_thermal_dispatch_template_network(CopperPlatePowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [120, 0, 120, 120, 24],
        c_sys14 => [120, 0, 120, 120, 24],
        c_sys14_dc => [120, 0, 120, 120, 24],
    )
    constraint_keys = [PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System)]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 240000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )

    for (ix, sys) in enumerate(systems)
        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)
        moi_tests(
            ps_model,
            test_results[sys][1],
            test_results[sys][2],
            test_results[sys][3],
            test_results[sys][4],
            test_results[sys][5],
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(ps_model, [MOI.OPTIMAL], test_obj_values[sys], 10000)
    end
    template = get_thermal_dispatch_template_network(
        NetworkModel(CopperPlatePowerModel; use_slacks = true),
    )
    ps_model_re = DecisionModel(
        template,
        PSB.build_system(PSITestSystems, "c_sys5_re");
        optimizer = GLPK_optimizer,
    )
    @test build!(ps_model_re; output_dir = mktempdir(; cleanup = true)) ==
          PSI.BuildStatus.BUILT
    psi_checksolve_test(ps_model_re, [MOI.OPTIMAL], 240000.0, 10000)
end

@testset "Network DC-PF with PTDF Model" begin
    template = get_thermal_dispatch_template_network(StandardPTDFModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
        PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => PTDF(c_sys5),
        c_sys14 => PTDF(c_sys14),
        c_sys14_dc => PTDF(c_sys14_dc),
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [264, 0, 264, 264, 168],
        c_sys14 => [600, 0, 600, 600, 504],
        c_sys14_dc => [600, 0, 648, 552, 456],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(
            NetworkModel(StandardPTDFModel; PTDF_matrix = PTDF_ref[sys]),
        )
        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)
        moi_tests(
            ps_model,
            test_results[sys][1],
            test_results[sys][2],
            test_results[sys][3],
            test_results[sys][4],
            test_results[sys][5],
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.ALMOST_OPTIMAL],
            test_obj_values[sys],
            10000,
        )
    end
    # PTDF input Error testing
    ps_model = DecisionModel(template, c_sys5; optimizer = GLPK_optimizer)
    @test build!(
        ps_model;
        console_level = Logging.AboveMaxLevel,  # Ignore expected errors.
        output_dir = mktempdir(; cleanup = true),
    ) == PSI.BuildStatus.FAILED
end

@testset "Network DC-PF with VirtualPTDF Model" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
        PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
    ]
    PTDF_ref = IdDict{System, VirtualPTDF}(
        c_sys5 => VirtualPTDF(c_sys5),
        c_sys14 => VirtualPTDF(c_sys14),
        c_sys14_dc => VirtualPTDF(c_sys14_dc),
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [264, 0, 264, 264, 168],
        c_sys14 => [600, 0, 600, 600, 504],
        c_sys14_dc => [600, 0, 648, 552, 456],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(StandardPTDFModel)
        template = get_thermal_dispatch_template_network(
            NetworkModel(StandardPTDFModel; PTDF_matrix = PTDF_ref[sys]),
        )
        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)
        moi_tests(
            ps_model,
            test_results[sys][1],
            test_results[sys][2],
            test_results[sys][3],
            test_results[sys][4],
            test_results[sys][5],
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.ALMOST_OPTIMAL],
            test_obj_values[sys],
            10000,
        )
    end
end

@testset "Sparse Network DC-PF with PTDFPowerModel" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
        PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
    ]
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [264, 0, 264, 264, 168],
        c_sys14 => [600, 0, 600, 600, 504],
        c_sys14_dc => [600, 0, 648, 552, 456],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(PTDFPowerModel)
        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)
        moi_tests(
            ps_model,
            test_results[sys][1],
            test_results[sys][2],
            test_results[sys][3],
            test_results[sys][4],
            test_results[sys][5],
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.ALMOST_OPTIMAL],
            test_obj_values[sys],
            10000,
        )
    end
end

@testset "Network DC lossless -PF network with PowerModels DCPlosslessForm" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(PSI.RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(PSI.RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(PSI.NodalBalanceActiveConstraint, PSY.Bus),
    ]
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [384, 0, 408, 408, 288],
        c_sys14 => [936, 0, 1080, 1080, 840],
        c_sys14_dc => [984, 0, 1080, 984, 840],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 342000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 143000.0,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(DCPPowerModel)
        ps_model = DecisionModel(template, sys; optimizer = ipopt_optimizer)
        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)
        moi_tests(
            ps_model,
            test_results[sys][1],
            test_results[sys][2],
            test_results[sys][3],
            test_results[sys][4],
            test_results[sys][5],
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
            test_obj_values[sys],
            1000,
        )
    end
end

@testset "Network Solve AC-PF PowerModels StandardACPModel" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    # Check for voltage and angle constraints
    constraint_keys = [
        PSI.ConstraintKey(RateLimitConstraintFromTo, PSY.Line),
        PSI.ConstraintKey(RateLimitConstraintToFrom, PSY.Line),
        PSI.ConstraintKey(PSI.NodalBalanceActiveConstraint, PSY.Bus),
        PSI.ConstraintKey(PSI.NodalBalanceReactiveConstraint, PSY.Bus),
    ]
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [1056, 0, 384, 384, 264],
        c_sys14 => [2832, 0, 720, 720, 696],
        c_sys14_dc => [2832, 0, 768, 672, 744],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(ACPPowerModel)
        ps_model = DecisionModel(template, sys; optimizer = ipopt_optimizer)
        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)
        moi_tests(
            ps_model,
            test_results[sys][1],
            test_results[sys][2],
            test_results[sys][3],
            test_results[sys][4],
            test_results[sys][5],
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(
            ps_model,
            [MOI.TIME_LIMIT, MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
            test_obj_values[sys],
            10000,
        )
    end
end

@testset "Network Solve AC-PF PowerModels NFAPowerModel" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [PSI.ConstraintKey(PSI.NodalBalanceActiveConstraint, PSY.Bus)]
    test_results = Dict{System, Vector{Int}}(
        c_sys5 => [264, 0, 264, 264, 120],
        c_sys14 => [600, 0, 600, 600, 336],
        c_sys14_dc => [648, 0, 648, 552, 384],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 300000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(NFAPowerModel)
        ps_model = DecisionModel(template, sys; optimizer = ipopt_optimizer)
        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)
        moi_tests(
            ps_model,
            test_results[sys][1],
            test_results[sys][2],
            test_results[sys][3],
            test_results[sys][4],
            test_results[sys][5],
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
            test_obj_values[sys],
            10000,
        )
    end
end

@testset "Other Network AC PowerModels models" begin
    networks = [#ACPPowerModel, Already tested
        ACRPowerModel,
        ACTPowerModel,
    ]
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    # TODO: add model specific constraints to this list. Voltages, etc.
    constraint_keys = [
        PSI.ConstraintKey(PSI.NodalBalanceActiveConstraint, PSY.Bus),
        PSI.ConstraintKey(PSI.NodalBalanceReactiveConstraint, PSY.Bus),
    ]
    ACR_test_results = Dict{System, Vector{Int}}(
        c_sys5 => [1056, 0, 240, 240, 264],
        c_sys14 => [2832, 0, 240, 240, 696],
        c_sys14_dc => [2832, 0, 336, 240, 744],
    )
    ACT_test_results = Dict{System, Vector{Int}}(
        c_sys5 => [1344, 0, 384, 384, 840],
        c_sys14 => [3792, 0, 720, 720, 2616],
        c_sys14_dc => [3696, 0, 768, 672, 2472],
    )
    test_results = Dict(zip(networks, [ACR_test_results, ACT_test_results]))
    for network in networks, sys in systems
        template = get_thermal_dispatch_template_network(network)
        ps_model = DecisionModel(template, sys; optimizer = fast_ipopt_optimizer)
        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)
        moi_tests(
            ps_model,
            test_results[network][sys][1],
            test_results[network][sys][2],
            test_results[network][sys][3],
            test_results[network][sys][4],
            test_results[network][sys][5],
            false,
        )
        @test ps_model.internal.container.pm !== nothing
    end
end

# TODO: Add constraint tests for these models, other is redundant with first test
@testset "Network DC-PF PowerModels quadratic loss approximations models" begin
    networks = [DCPLLPowerModel, LPACCPowerModel]
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    # TODO: add model specific constraints to this list. Bi-directional flows etc
    constraint_keys = [PSI.ConstraintKey(PSI.NodalBalanceActiveConstraint, PSY.Bus)]
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )
    DCPLL_test_results = Dict{System, Vector{Int}}(
        c_sys5 => [528, 0, 408, 408, 288],
        c_sys14 => [1416, 0, 1080, 1080, 840],
        c_sys14_dc => [1416, 0, 1080, 984, 840],
    )
    LPACC_test_results = Dict{System, Vector{Int}}(
        c_sys5 => [1200, 0, 384, 384, 840],
        c_sys14 => [3312, 0, 720, 720, 2616],
        c_sys14_dc => [3264, 0, 768, 672, 2472],
    )
    test_results = Dict(zip(networks, [DCPLL_test_results, LPACC_test_results]))
    for network in networks, (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(network)
        ps_model = DecisionModel(template, sys; optimizer = ipopt_optimizer)
        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)
        moi_tests(
            ps_model,
            test_results[network][sys][1],
            test_results[network][sys][2],
            test_results[network][sys][3],
            test_results[network][sys][4],
            test_results[network][sys][5],
            false,
        )
        @test ps_model.internal.container.pm !== nothing
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
            test_obj_values[sys],
            10000,
        )
    end
end

@testset "Network Unsupported Power Model Formulations" begin
    for network in PSI.UNSUPPORTED_POWERMODELS
        template = get_thermal_dispatch_template_network(network)
        ps_model = DecisionModel(
            template,
            PSB.build_system(PSITestSystems, "c_sys5");
            optimizer = ipopt_optimizer,
        )
        @test build!(
            ps_model;
            console_level = Logging.AboveMaxLevel,  # Ignore expected errors.
            output_dir = mktempdir(; cleanup = true),
        ) == PSI.BuildStatus.FAILED
    end
end

@testset "2 Subnetworks DC-PF with CopperPlatePowerModel" begin
    c_sys5 = PSB.build_system(PSISystems, "2Area 5 Bus System")
    # Test passing a VirtualPTDF Model
    template = get_thermal_dispatch_template_network(NetworkModel(CopperPlatePowerModel))
    ps_model = DecisionModel(template, c_sys5; optimizer = HiGHS_optimizer)

    @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.BuildStatus.BUILT
    solve!(ps_model)

    moi_tests(ps_model, 264, 0, 288, 240, 48, false)

    opt_container = PSI.get_optimization_container(ps_model)
    copper_plate_constraints =
        PSI.get_constraint(opt_container, CopperPlateBalanceConstraint(), PSY.System)
    @test size(copper_plate_constraints) == (2, 24)

    psi_checksolve_test(ps_model, [MOI.OPTIMAL], 480288, 100)

    results = ProblemResults(ps_model)
    hvdc_flow = read_variable(results, "FlowActivePowerVariable__HVDCLine")
    @test all(hvdc_flow[!, "nodeC-nodeC2"] .<= 200)
    @test all(hvdc_flow[!, "nodeC-nodeC2"] .>= -200)

    load = read_parameter(results, "ActivePowerTimeSeriesParameter__PowerLoad")
    thermal_gen = read_variable(results, "ActivePowerVariable__ThermalStandard")

    zone_1_load = sum(eachcol(load[!, ["Load-nodeC", "Load-nodeD", "Load-nodeB"]]))
    zone_1_gen = sum(
        eachcol(thermal_gen[!, ["Solitude", "Park City", "Sundance", "Brighton", "Alta"]]),
    )
    @test all(
        isapprox.(
            sum(zone_1_gen .+ zone_1_load .- hvdc_flow[!, "nodeC-nodeC2"]; dims = 2),
            0.0;
            atol = 1e-3,
        ),
    )

    zone_2_load = sum(eachcol(load[!, ["Load-nodeC2", "Load-nodeD2", "Load-nodeB2"]]))
    zone_2_gen = sum(
        eachcol(
            thermal_gen[
                !,
                ["Solitude-2", "Park City-2", "Sundance-2", "Brighton-2", "Alta-2"],
            ],
        ),
    )
    @test all(
        isapprox.(
            sum(zone_2_gen .+ zone_2_load .+ hvdc_flow[!, "nodeC-nodeC2"]; dims = 2),
            0.0;
            atol = 1e-3,
        ),
    )

    # Test forcing flows to 0.0
    hvdc_link = get_component(PSY.HVDCLine, c_sys5, "nodeC-nodeC2")
    set_active_power_limits_from!(hvdc_link, (min = 0.0, max = 0.0))
    set_active_power_limits_to!(hvdc_link, (min = 0.0, max = 0.0))

    # Test not passing the PTDF to the Template
    template = get_thermal_dispatch_template_network(NetworkModel(StandardPTDFModel))
    ps_model = DecisionModel(template, c_sys5; optimizer = HiGHS_optimizer)
    @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.BuildStatus.BUILT
    solve!(ps_model)

    opt_container = PSI.get_optimization_container(ps_model)
    copper_plate_constraints =
        PSI.get_constraint(opt_container, CopperPlateBalanceConstraint(), PSY.System)

    results = ProblemResults(ps_model)
    hvdc_flow = read_variable(results, "FlowActivePowerVariable__HVDCLine")
    @test all(hvdc_flow[!, "nodeC-nodeC2"] .== 0.0)
    @test all(hvdc_flow[!, "nodeC-nodeC2"] .== 0.0)

    load = read_parameter(results, "ActivePowerTimeSeriesParameter__PowerLoad")
    thermal_gen = read_variable(results, "ActivePowerVariable__ThermalStandard")

    zone_1_load = sum(eachcol(load[!, ["Load-nodeC", "Load-nodeD", "Load-nodeB"]]))
    zone_1_gen = sum(
        eachcol(thermal_gen[!, ["Solitude", "Park City", "Sundance", "Brighton", "Alta"]]),
    )
    @test all(isapprox.(sum(zone_1_gen .+ zone_1_load; dims = 2), 0.0; atol = 1e-3))

    zone_2_load = sum(eachcol(load[!, ["Load-nodeC2", "Load-nodeD2", "Load-nodeB2"]]))
    zone_2_gen = sum(
        eachcol(
            thermal_gen[
                !,
                ["Solitude-2", "Park City-2", "Sundance-2", "Brighton-2", "Alta-2"],
            ],
        ),
    )
    @test all(isapprox.(sum(zone_2_gen .+ zone_2_load; dims = 2), 0.0; atol = 1e-3))
end

@testset "2 Subnetworks DC-PF with PTDF Model" begin
    c_sys5 = PSB.build_system(PSISystems, "2Area 5 Bus System")
    # Test passing a VirtualPTDF Model
    template = get_thermal_dispatch_template_network(
        NetworkModel(StandardPTDFModel; PTDF_matrix = VirtualPTDF(c_sys5)),
    )
    ps_model = DecisionModel(template, c_sys5; optimizer = HiGHS_optimizer)

    @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.BuildStatus.BUILT
    solve!(ps_model)

    moi_tests(ps_model, 552, 0, 576, 528, 336, false)

    opt_container = PSI.get_optimization_container(ps_model)
    copper_plate_constraints =
        PSI.get_constraint(opt_container, CopperPlateBalanceConstraint(), PSY.System)
    @test size(copper_plate_constraints) == (2, 24)

    psi_checksolve_test(ps_model, [MOI.OPTIMAL], 684763, 100)

    results = ProblemResults(ps_model)
    hvdc_flow = read_variable(results, "FlowActivePowerVariable__HVDCLine")
    @test all(hvdc_flow[!, "nodeC-nodeC2"] .<= 200)
    @test all(hvdc_flow[!, "nodeC-nodeC2"] .>= -200)

    load = read_parameter(results, "ActivePowerTimeSeriesParameter__PowerLoad")
    thermal_gen = read_variable(results, "ActivePowerVariable__ThermalStandard")

    zone_1_load = sum(eachcol(load[!, ["Load-nodeC", "Load-nodeD", "Load-nodeB"]]))
    zone_1_gen = sum(
        eachcol(thermal_gen[!, ["Solitude", "Park City", "Sundance", "Brighton", "Alta"]]),
    )
    @test all(
        isapprox.(
            sum(zone_1_gen .+ zone_1_load .- hvdc_flow[!, "nodeC-nodeC2"]; dims = 2),
            0.0;
            atol = 1e-3,
        ),
    )

    zone_2_load = sum(eachcol(load[!, ["Load-nodeC2", "Load-nodeD2", "Load-nodeB2"]]))
    zone_2_gen = sum(
        eachcol(
            thermal_gen[
                !,
                ["Solitude-2", "Park City-2", "Sundance-2", "Brighton-2", "Alta-2"],
            ],
        ),
    )
    @test all(
        isapprox.(
            sum(zone_2_gen .+ zone_2_load .+ hvdc_flow[!, "nodeC-nodeC2"]; dims = 2),
            0.0;
            atol = 1e-3,
        ),
    )

    # Test forcing flows to 0.0
    hvdc_link = get_component(PSY.HVDCLine, c_sys5, "nodeC-nodeC2")
    set_active_power_limits_from!(hvdc_link, (min = 0.0, max = 0.0))
    set_active_power_limits_to!(hvdc_link, (min = 0.0, max = 0.0))

    # Test not passing the PTDF to the Template
    template = get_thermal_dispatch_template_network(NetworkModel(StandardPTDFModel))
    ps_model = DecisionModel(template, c_sys5; optimizer = HiGHS_optimizer)
    @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.BuildStatus.BUILT
    solve!(ps_model)

    opt_container = PSI.get_optimization_container(ps_model)
    copper_plate_constraints =
        PSI.get_constraint(opt_container, CopperPlateBalanceConstraint(), PSY.System)

    results = ProblemResults(ps_model)
    hvdc_flow = read_variable(results, "FlowActivePowerVariable__HVDCLine")
    @test all(hvdc_flow[!, "nodeC-nodeC2"] .== 0.0)
    @test all(hvdc_flow[!, "nodeC-nodeC2"] .== 0.0)

    load = read_parameter(results, "ActivePowerTimeSeriesParameter__PowerLoad")
    thermal_gen = read_variable(results, "ActivePowerVariable__ThermalStandard")

    zone_1_load = sum(eachcol(load[!, ["Load-nodeC", "Load-nodeD", "Load-nodeB"]]))
    zone_1_gen = sum(
        eachcol(thermal_gen[!, ["Solitude", "Park City", "Sundance", "Brighton", "Alta"]]),
    )
    @test all(isapprox.(sum(zone_1_gen .+ zone_1_load; dims = 2), 0.0; atol = 1e-3))

    zone_2_load = sum(eachcol(load[!, ["Load-nodeC2", "Load-nodeD2", "Load-nodeB2"]]))
    zone_2_gen = sum(
        eachcol(
            thermal_gen[
                !,
                ["Solitude-2", "Park City-2", "Sundance-2", "Brighton-2", "Alta-2"],
            ],
        ),
    )
    @test all(isapprox.(sum(zone_2_gen .+ zone_2_load; dims = 2), 0.0; atol = 1e-3))
end
