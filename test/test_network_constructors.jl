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
    ]
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    for (network, solver) in networks
        template = get_thermal_dispatch_template_network(network)
        ps_model = OperationsProblem(template, c_sys5; optimizer = solver)
        @test build!(ps_model; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        @test !isnothing(ps_model.internal.optimization_container.pm)
        @test :nodal_balance_active in
              keys(ps_model.internal.optimization_container.expressions)
    end
end

@testset "Network Copper Plate" begin
    template = get_thermal_dispatch_template_network(CopperPlatePowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    parameters = [true, false]
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [120, 0, 120, 120, 24],
        c_sys14 => [120, 0, 120, 120, 24],
        c_sys14_dc => [120, 0, 120, 120, 24],
    )
    constraint_names = [:CopperPlateBalance]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 240000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )

    for (ix, sys) in enumerate(systems), p in parameters
        ps_model =
            OperationsProblem(template, sys; optimizer = OSQP_optimizer, use_parameters = p)

        @test build!(ps_model; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_names)
        moi_tests(
            ps_model,
            p,
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
    ps_model_re = OperationsProblem(
        template,
        PSB.build_system(PSITestSystems, "c_sys5_re");
        optimizer = GLPK_optimizer,
        use_parameters = true,
        balance_slack_variables = true,
    )
    @test build!(ps_model_re; output_dir = mktempdir(cleanup = true)) ==
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
    constraint_names =
        [:RateLimit_lb__Line, :RateLimit_ub__Line, :CopperPlateBalance, :network_flow]
    parameters = [true, false]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => PTDF(c_sys5),
        c_sys14 => PTDF(c_sys14),
        c_sys14_dc => PTDF(c_sys14_dc),
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [264, 0, 264, 264, 168],
        c_sys14 => [600, 0, 600, 600, 504],
        c_sys14_dc => [600, 48, 552, 552, 456],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )
    for (ix, sys) in enumerate(systems), p in parameters
        ps_model = OperationsProblem(
            template,
            sys;
            optimizer = OSQP_optimizer,
            use_parameters = p,
            PTDF = PTDF_ref[sys],
        )

        @test build!(ps_model; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_names)
        moi_tests(
            ps_model,
            p,
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
    ps_model = OperationsProblem(template, c_sys5; optimizer = GLPK_optimizer)
    # Not capturing the logs
    # @test_logs (:error,) match_mode = :any
    @test build!(
        ps_model;
        output_dir = mktempdir(cleanup = true),
    ) == PSI.BuildStatus.FAILED
end

@testset "Network DC lossless -PF network with PowerModels DCPlosslessForm" begin
    template = get_thermal_dispatch_template_network(DCPPowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_names = [
        :RateLimit_ub__Line,
        :RateLimit_lb__Line,
        PSI.make_constraint_name(PSI.NODAL_BALANCE_ACTIVE, PSY.Bus),
    ]
    parameters = [true, false]
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [384, 0, 408, 408, 288],
        c_sys14 => [936, 0, 1080, 1080, 840],
        c_sys14_dc => [984, 48, 984, 984, 840],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 342000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )
    for (ix, sys) in enumerate(systems), p in parameters
        ps_model =
            OperationsProblem(template, sys; optimizer = OSQP_optimizer, use_parameters = p)
        @test build!(ps_model; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_names)
        moi_tests(
            ps_model,
            p,
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
            1000,
        )
    end
end

@testset "Network Solve AC-PF PowerModels StandardACPModel" begin
    template = get_thermal_dispatch_template_network(ACPPowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    # Check for voltage and angle constraints
    constraint_names = [
        :RateLimitFT__Line,
        :RateLimitTF__Line,
        PSI.make_constraint_name(PSI.NODAL_BALANCE_ACTIVE, PSY.Bus),
        PSI.make_constraint_name(PSI.NODAL_BALANCE_REACTIVE, PSY.Bus),
    ]
    parameters = [true, false]
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [1056, 0, 384, 384, 264],
        c_sys14 => [2832, 0, 720, 720, 696],
        c_sys14_dc => [2832, 96, 672, 672, 744],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )
    for (ix, sys) in enumerate(systems), p in parameters
        ps_model = OperationsProblem(
            template,
            sys;
            optimizer = ipopt_optimizer,
            use_parameters = p,
        )
        @test build!(ps_model; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_names)
        moi_tests(
            ps_model,
            p,
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

# TODO: Add constraint tests for these models, other is redundant with first test
@testset "Network Solve AC-PF PowerModels NFAPowerModel" begin
    template = get_thermal_dispatch_template_network(NFAPowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_names = [PSI.make_constraint_name(PSI.NODAL_BALANCE_ACTIVE, PSY.Bus)]
    parameters = [true, false]
    # TODO: Enable these tests
    #test_results = Dict{System, Vector{Int}}(
    #    c_sys5 => [384, 0, 408, 408, 288],
    #    c_sys14 => [936, 0, 1080, 1080, 840],
    #    c_sys14_dc => [984, 48, 984, 984, 840],
    #)
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 300000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )
    for (ix, sys) in enumerate(systems), p in parameters
        ps_model =
            OperationsProblem(template, sys; optimizer = OSQP_optimizer, use_parameters = p)
        @test build!(ps_model; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_names)
        # TODO: Enable these tests
        # moi_tests(
        #     ps_model,
        #     p,
        #     test_results[sys][1],
        #     test_results[sys][2],
        #     test_results[sys][3],
        #     test_results[sys][4],
        #     test_results[sys][5],
        #     false,
        # )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.ALMOST_OPTIMAL],
            test_obj_values[sys],
            10000,
        )
    end
end

# TODO: Add constraint tests for these models, other is redundant with first test
@testset "Other Network AC PowerModels models" begin
    # TODO: Enable MOI tests for # of constraints
    networks = [#ACPPowerModel, Already tested
        ACRPowerModel,
        ACTPowerModel,
    ]
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    # TODO: add model specific constraints to this list. Voltages, etc.
    constraint_names = [PSI.make_constraint_name(PSI.NODAL_BALANCE_ACTIVE, PSY.Bus)]
    # TODO: Enable these tests
    #test_results = Dict{System, Vector{Int}}(
    #    c_sys5 => [384, 0, 408, 408, 288],
    #    c_sys14 => [936, 0, 1080, 1080, 840],
    #    c_sys14_dc => [984, 48, 984, 984, 840],
    #)

    for network in networks, sys in systems
        template = get_thermal_dispatch_template_network(network)
        ps_model = OperationsProblem(
            template,
            sys;
            optimizer = fast_ipopt_optimizer,
            use_parameters = true,
        )
        @test build!(ps_model; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_names)
        # TODO: Enable these tests
        # moi_tests(
        #     ps_model,
        #     p,
        #     test_results[sys][1],
        #     test_results[sys][2],
        #     test_results[sys][3],
        #     test_results[sys][4],
        #     test_results[sys][5],
        #     false,
        # )
        @test !isnothing(ps_model.internal.optimization_container.pm)
    end
end

# TODO: Add constraint tests for these models, other is redundant with first test
@testset "Network AC-PF PowerModels quadratic loss approximations models" begin
    networks = [DCPLLPowerModel, LPACCPowerModel]
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    # TODO: add model specific constraints to this list. Bi-direccional flows etc
    constraint_names = [PSI.make_constraint_name(PSI.NODAL_BALANCE_ACTIVE, PSY.Bus)]
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )
    # TODO: Enable these tests
    #test_results = Dict{System, Vector{Int}}(
    #    c_sys5 => [384, 0, 408, 408, 288],
    #    c_sys14 => [936, 0, 1080, 1080, 840],
    #    c_sys14_dc => [984, 48, 984, 984, 840],
    #)
    for network in networks, sys in systems
        template = get_thermal_dispatch_template_network(network)
        ps_model = OperationsProblem(
            template,
            sys;
            optimizer = ipopt_optimizer,
            use_parameters = true,
        )
        @test build!(ps_model; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_names)
        # TODO: Enable these tests
        # moi_tests(
        #     ps_model,
        #     p,
        #     test_results[sys][1],
        #     test_results[sys][2],
        #     test_results[sys][3],
        #     test_results[sys][4],
        #     test_results[sys][5],
        #     false,
        # )
        @test !isnothing(ps_model.internal.optimization_container.pm)
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
        ps_model = OperationsProblem(
            template,
            PSB.build_system(PSITestSystems, "c_sys5");
            optimizer = ipopt_optimizer,
        )
        # Not capturing the logs
        # @test_logs (:error,) match_mode = :any
        @test build!(
            ps_model;
            output_dir = mktempdir(cleanup = true),
        ) == PSI.BuildStatus.FAILED
    end
end
