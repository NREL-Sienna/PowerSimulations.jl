thermal_model = DeviceModel(ThermalStandard, ThermalDispatch)
load_model = DeviceModel(PowerLoad, StaticPowerLoad)
line_model = DeviceModel(Line, StaticLine)
transformer_model = DeviceModel(Transformer2W, StaticTransformer)
ttransformer_model = DeviceModel(TapTransformer, StaticTransformer)
dc_line = DeviceModel(HVDCLine, HVDCDispatch)

@testset "Network Copper Plate" begin
    network = CopperPlatePowerModel
    systems = [c_sys5, c_sys14_dc] #c_sys14
    parameters = [true, false]
    test_results = Dict{System, Vector{Int64}}(c_sys5 => [120, 0, 120, 120, 24],
                                                   c_sys14 => [120, 0, 120, 120, 24],
                                                   c_sys14_dc => [120, 0, 120, 120, 24])
    constraint_names = [:CopperPlateBalance]
    objfuncs = [GAEVF, GQEVF, GQEVF]

    for (ix, sys) in enumerate(systems), p in parameters
        ps_model = OperationsProblem(TestOpProblem, network, sys; optimizer = OSQP_optimizer, use_parameters = p)
        construct_device!(ps_model, :Thermal, thermal_model; use_parameters = p);
        construct_device!(ps_model, :Load, load_model; use_parameters = p);
        construct_network!(ps_model, network; use_parameters = p);
        construct_device!(ps_model, :Line, line_model; use_parameters = p);
        construct_device!(ps_model, :Tf, transformer_model; use_parameters = p);
        construct_device!(ps_model, :TTf, ttransformer_model; use_parameters = p);
        construct_device!(ps_model, :DCLine, dc_line; use_parameters = p);

        moi_tests(ps_model, p, test_results[sys][1],
                                test_results[sys][2],
                                test_results[sys][3],
                                test_results[sys][4],
                                test_results[sys][5], false)
        psi_constraint_test(ps_model, constraint_names)
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(ps_model, [MOI.OPTIMAL])
    end
end

@testset "Network DC-PF with PTDF formulation" begin
    network = StandardPTDFModel
    systems = [c_sys5, c_sys14_dc] #c_sys14
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_names = [:RateLimit_lb_Line, :RateLimit_ub_Line, :nodal_balance, :network_flow]
    parameters = [true, false]
    PTDF_ref = Dict{System, PTDF}(c_sys5 => PTDF5, c_sys14 => PTDF14, c_sys14_dc => PTDF14_dc);
    test_results = Dict{System, Vector{Int64}}(c_sys5 => [264, 0, 264, 264, 264],
                                                    c_sys14 => [600, 0, 600, 600, 816],
                                                    c_sys14_dc => [600, 48, 552, 552, 768])

    for (ix, sys) in enumerate(systems), p in parameters
        ps_model = OperationsProblem(TestOpProblem, network, sys; optimizer = OSQP_optimizer, use_parameters = p)
        construct_device!(ps_model, :Thermal, thermal_model; use_parameters = p);
        construct_device!(ps_model, :Load, load_model; use_parameters = p);
        construct_network!(ps_model, network; PTDF = PTDF_ref[sys], use_parameters = p);
        construct_device!(ps_model, :Line, line_model; use_parameters = p);
        construct_device!(ps_model, :Tf, transformer_model; use_parameters = p);
        construct_device!(ps_model, :TTf, ttransformer_model; use_parameters = p);
        construct_device!(ps_model, :DCLine, dc_line; use_parameters = p);

        moi_tests(ps_model, p, test_results[sys][1],
                                test_results[sys][2],
                                test_results[sys][3],
                                test_results[sys][4],
                                test_results[sys][5], false)
        psi_constraint_test(ps_model, constraint_names)
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(ps_model, [MOI.OPTIMAL])
    end

    #PTDF input Error testing
    ps_model = OperationsProblem(TestOpProblem, network, c_sys5; optimizer = GLPK_optimizer)
    construct_device!(ps_model, :Thermal, thermal_model);
    construct_device!(ps_model, :Load, load_model);
    @test_throws ArgumentError construct_network!(ps_model, network)

end

@testset "Network DC lossless -PF network with PowerModels DCPlosslessForm" begin
    network = DCPPowerModel
    systems = [c_sys5, c_sys14_dc] #c_sys14
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_names = [:RateLimit_ub_Line, :RateLimit_lb_Line]
    parameters = [true, false]
    test_results = Dict{System, Vector{Int64}}(c_sys5 => [384, 0, 408, 408, 288],
                                                    c_sys14 => [936, 0, 1080, 1080, 840],
                                                    c_sys14_dc => [984, 48, 984, 984, 840])

    for (ix, sys) in enumerate(systems), p in parameters
        ps_model = OperationsProblem(TestOpProblem, network, sys; optimizer = OSQP_optimizer, use_parameters = p)
        construct_device!(ps_model, :Thermal, thermal_model; use_parameters = p);
        construct_device!(ps_model, :Load, load_model; use_parameters = p);
        construct_network!(ps_model, network; use_parameters = p);
        construct_device!(ps_model, :Line, line_model; use_parameters = p);
        construct_device!(ps_model, :Tf, transformer_model; use_parameters = p);
        construct_device!(ps_model, :TTf, ttransformer_model; use_parameters = p);
        construct_device!(ps_model, :DCLine, dc_line; use_parameters = p);

        moi_tests(ps_model, p, test_results[sys][1],
                                test_results[sys][2],
                                test_results[sys][3],
                                test_results[sys][4],
                                test_results[sys][5], false)
        psi_constraint_test(ps_model, constraint_names)
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(ps_model, [MOI.OPTIMAL])
    end

end

@testset  "Network Solve AC-PF PowerModels StandardACPModel" begin
    network = ACPPowerModel
    systems = [c_sys5, c_sys14_dc] #c_sys14
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_names = [:RateLimitFT_Line, :RateLimitTF_Line]
    parameters = [true, false]
    test_results = Dict{System, Vector{Int64}}(c_sys5 => [1056, 0, 384, 384, 264],
                                                    c_sys14 => [2832, 0, 720, 720, 696],
                                                    c_sys14_dc => [2832, 96, 672, 672, 744]) # TODO: changed the interval constraint number to 336 from 240. double check

    for (ix, sys) in enumerate(systems), p in parameters
        ps_model = OperationsProblem(TestOpProblem, network, sys; optimizer = ipopt_optimizer, use_parameters = p)
        construct_device!(ps_model, :Thermal, thermal_model; use_parameters = p);
        construct_device!(ps_model, :Load, load_model; use_parameters = p);
        construct_network!(ps_model, network; use_parameters = p);
        construct_device!(ps_model, :Line, line_model; use_parameters = p);
        construct_device!(ps_model, :Tf, transformer_model; use_parameters = p);
        construct_device!(ps_model, :TTf, ttransformer_model; use_parameters = p);
        construct_device!(ps_model, :DCLine, dc_line; use_parameters = p);

        moi_tests(ps_model, p, test_results[sys][1],
                                test_results[sys][2],
                                test_results[sys][3],
                                test_results[sys][4],
                                test_results[sys][5], false)
        psi_constraint_test(ps_model, constraint_names)
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(ps_model, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED])
    end
end

@testset  "Network Solve AC-PF PowerModels linear approximation models" begin
    networks = [DCPPowerModel, NFAPowerModel]
    systems = [c_sys5, c_sys14_dc] #c_sys14
    p = true
    for network in networks, sys in systems
        @info "Testing construction of a $(network) network"
        ps_model = OperationsProblem(TestOpProblem, network, sys; optimizer = OSQP_optimizer, use_parameters = p)
        construct_device!(ps_model, :Thermal, thermal_model; use_parameters = p);
        construct_device!(ps_model, :Load, load_model; use_parameters = p);
        construct_network!(ps_model, network; use_parameters = p);
        construct_device!(ps_model, :Line, line_model; use_parameters = p);
        construct_device!(ps_model, :DCLine, dc_line; use_parameters = p);
        psi_checksolve_test(ps_model, [MOI.OPTIMAL])

    end

end

@testset  "Network AC-PF PowerModels non-convex models" begin
    networks = [#ACPPowerModel, Already tested
                ACRPowerModel,
                ACTPowerModel
                ]
    systems = [c_sys5, c_sys14_dc] #c_sys14

    for network in networks, sys in systems
        @info "Testing construction of a $(network) network"
        ps_model = OperationsProblem(TestOpProblem, network, sys; optimizer = ipopt_optimizer)
        construct_device!(ps_model, :Thermal, thermal_model);
        construct_device!(ps_model, :Load, load_model);
        construct_network!(ps_model, network);
        construct_device!(ps_model, :Line, line_model);
        @test !isnothing(ps_model.psi_container.pm)
    end

end

@testset  "Network AC-PF PowerModels quadratic loss approximations models" begin
    networks = [DCPLLPowerModel, LPACCPowerModel]
    systems = [c_sys5, c_sys14_dc] #c_sys14

    for network in networks, sys in systems
        @info "Testing construction of a $(network) network"
        ps_model = OperationsProblem(TestOpProblem, network, sys; optimizer = ipopt_optimizer)
        construct_device!(ps_model, :Thermal, thermal_model);
        construct_device!(ps_model, :Load, load_model);
        construct_network!(ps_model, network);
        construct_device!(ps_model, :Line, line_model);
        construct_device!(ps_model, :DCLine, dc_line);
        @test !isnothing(ps_model.psi_container.pm)
    end

end

@testset  "Network AC-PF PowerModels quadratic relaxations models" begin
    networks = [ SOCWRPowerModel,
                 QCRMPowerModel,
                 QCLSPowerModel,
                 ]
    systems = [c_sys5, c_sys14_dc] #c_sys14

    for network in networks, sys in systems
        @info "Testing construction of a $(network) network"
        ps_model = OperationsProblem(TestOpProblem, network, sys; optimizer = ipopt_optimizer)
        construct_device!(ps_model, :Thermal, thermal_model);
        construct_device!(ps_model, :Load, load_model);
        construct_network!(ps_model, network);
        construct_device!(ps_model, :Line, line_model);
        construct_device!(ps_model, :DCLine, dc_line);
        @test !isnothing(ps_model.psi_container.pm)
    end

end

@testset  "Network Unsupported Power Model Formulations" begin
incompat_list = [PM.SDPWRMPowerModel,
                 PM.SparseSDPWRMPowerModel,
                 PM.SOCBFPowerModel,
                 PM.SOCBFConicPowerModel]

    for network in incompat_list
        ps_model = OperationsProblem(TestOpProblem, network, c_sys5; optimizer = ipopt_optimizer)
        construct_device!(ps_model, :Thermal, thermal_model);
        construct_device!(ps_model, :Load, load_model);

        @test_throws ArgumentError construct_network!(ps_model, network);
    end

end
