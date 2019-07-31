thermal_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch)
load_model = DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad)
line_model = DeviceModel(PSY.Line, PSI.StaticLine)
transformer_model = DeviceModel(PSY.Transformer2W, PSI.StaticTransformer)
ttransformer_model = DeviceModel(PSY.TapTransformer, PSI.StaticTransformer)
dc_line = DeviceModel(PSY.HVDCLine, PSI.HVDCDispatch)

@testset "Network Copper Plate" begin
    network = CopperPlatePowerModel
    systems = [c_sys5, c_sys14, c_sys14_dc]
    parameters = [true, false]
    test_results = Dict{PSY.System, Vector{Int64}}(c_sys5 => [120, 120, 0, 0, 24],
                                                   c_sys14 => [120, 120, 0, 0, 24],
                                                   c_sys14_dc => [120, 120, 0, 0, 24])
    constraint_names = [:CopperPlateBalance]
    objfuncs = [GAEVF, GQEVF, GQEVF]

    for (ix, sys) in enumerate(systems), p in parameters
        ps_model = OperationModel(TestOptModel, network, sys; optimizer = OSQP_optimizer, parameters = p)
        construct_device!(ps_model, :Thermal, thermal_model; parameters = p);
        construct_device!(ps_model, :Load, load_model; parameters = p);
        construct_network!(ps_model, network; parameters = p);
        construct_device!(ps_model, :Line, line_model; parameters = p);
        construct_device!(ps_model, :Tf, transformer_model; parameters = p);
        construct_device!(ps_model, :TTf, ttransformer_model; parameters = p);
        construct_device!(ps_model, :DCLine, dc_line; parameters = p);

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
    network = StandardPTDFForm
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_names = [:RateLimit_Line, :nodal_balance, :network_flow]
    parameters = [true, false]
    PTDF_ref = Dict{PSY.System, PSY.PTDF}(c_sys5 => PTDF5, c_sys14 => PTDF14, c_sys14_dc => PTDF14_dc);
    test_results = Dict{PSY.System, Vector{Int64}}(c_sys5 => [264, 264, 0, 0, 264],
                                                    c_sys14 => [600, 600, 0, 0, 816],
                                                    c_sys14_dc => [600, 600, 0, 0, 768])

    for (ix, sys) in enumerate(systems), p in parameters
        ps_model = OperationModel(TestOptModel, network, sys; optimizer = OSQP_optimizer, parameters = p)
        construct_device!(ps_model, :Thermal, thermal_model; parameters = p);
        construct_device!(ps_model, :Load, load_model; parameters = p);
        construct_network!(ps_model, network; PTDF = PTDF_ref[sys], parameters = p);
        construct_device!(ps_model, :Line, line_model; parameters = p);
        construct_device!(ps_model, :Tf, transformer_model; parameters = p);
        construct_device!(ps_model, :TTf, ttransformer_model; parameters = p);
        construct_device!(ps_model, :DCLine, dc_line; parameters = p);

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
    ps_model = OperationModel(TestOptModel, network, c_sys5; optimizer = GLPK_optimizer)
    construct_device!(ps_model, :Thermal, thermal_model);
    construct_device!(ps_model, :Load, load_model);
    @test_throws ArgumentError construct_network!(ps_model, network)

end

@testset "Network DC lossless -PF network with PowerModels DCPlosslessForm" begin
    network = PM.DCPlosslessForm
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_names = [:RateLimit_Line]
    parameters = [true, false]
    test_results = Dict{PSY.System, Vector{Int64}}(c_sys5 => [384, 264, 144, 144, 288],
                                                    c_sys14 => [936, 600, 480, 480, 840],
                                                    c_sys14_dc => [984, 600, 432, 432, 840])

    for (ix, sys) in enumerate(systems), p in parameters
        ps_model = OperationModel(TestOptModel, network, sys; optimizer = OSQP_optimizer, parameters = p)
        construct_device!(ps_model, :Thermal, thermal_model; parameters = p);
        construct_device!(ps_model, :Load, load_model; parameters = p);
        construct_network!(ps_model, network; parameters = p);
        construct_device!(ps_model, :Line, line_model; parameters = p);
        construct_device!(ps_model, :Tf, transformer_model; parameters = p);
        construct_device!(ps_model, :TTf, ttransformer_model; parameters = p);
        construct_device!(ps_model, :DCLine, dc_line; parameters = p);

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

@testset  "Network Solve AC-PF PowerModels StandardACPForm" begin
    network = PM.StandardACPForm
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_names = [:RateLimitFT_Line, :RateLimitTF_Line]
    parameters = [true, false]
    test_results = Dict{PSY.System, Vector{Int64}}(c_sys5 => [1056, 240, 144, 144, 240],
                                                    c_sys14 => [2832, 240, 480, 480, 672],
                                                    c_sys14_dc => [2832, 336, 432, 432, 720]) # TODO: changed the interval constraint number to 336 from 240. double check

    for (ix, sys) in enumerate(systems), p in parameters
        ps_model = OperationModel(TestOptModel, network, sys; optimizer = ipopt_optimizer, parameters = p)
        construct_device!(ps_model, :Thermal, thermal_model; parameters = p);
        construct_device!(ps_model, :Load, load_model; parameters = p);
        construct_network!(ps_model, network; parameters = p);
        construct_device!(ps_model, :Line, line_model; parameters = p);
        construct_device!(ps_model, :Tf, transformer_model; parameters = p);
        construct_device!(ps_model, :TTf, ttransformer_model; parameters = p);
        construct_device!(ps_model, :DCLine, dc_line; parameters = p);

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
    networks = [PM.DCPlosslessForm, PM.NFAForm]
    systems = [c_sys5, c_sys14, c_sys14_dc]
    p = true
    for network in networks, sys in systems
        @info "Testing construction of a $(network) network"
        ps_model = OperationModel(TestOptModel, network, sys; optimizer = OSQP_optimizer, parameters = p)
        construct_device!(ps_model, :Thermal, thermal_model; parameters = p);
        construct_device!(ps_model, :Load, load_model; parameters = p);
        construct_network!(ps_model, network; parameters = p);
        construct_device!(ps_model, :Line, line_model; parameters = p);
        construct_device!(ps_model, :DCLine, dc_line; parameters = p);
        psi_checksolve_test(ps_model, [MOI.OPTIMAL])

    end

end

@testset  "Network AC-PF PowerModels non-convex models" begin
    networks = [#PM.StandardACPForm, Already tested
                PM.StandardACRForm,
                PM.StandardACTForm
                ]
    systems = [c_sys5, c_sys14, c_sys14_dc]

    for network in networks, sys in systems
        @info "Testing construction of a $(network) network"
        ps_model = OperationModel(TestOptModel, network, sys; optimizer = ipopt_optimizer)
        construct_device!(ps_model, :Thermal, thermal_model);
        construct_device!(ps_model, :Load, load_model);
        construct_network!(ps_model, network);
        construct_device!(ps_model, :Line, line_model);
        @test !isnothing(ps_model.canonical.pm_model)
    end

end

@testset  "Network AC-PF PowerModels quadratic loss approximations models" begin
    networks = [PM.StandardDCPLLForm, PM.AbstractLPACCForm]
    systems = [c_sys5, c_sys14, c_sys14_dc]

    for network in networks, sys in systems
        @info "Testing construction of a $(network) network"
        ps_model = OperationModel(TestOptModel, network, sys; optimizer = ipopt_optimizer)
        construct_device!(ps_model, :Thermal, thermal_model);
        construct_device!(ps_model, :Load, load_model);
        construct_network!(ps_model, network);
        construct_device!(ps_model, :Line, line_model);
        construct_device!(ps_model, :DCLine, dc_line);
        @test !isnothing(ps_model.canonical.pm_model)
    end

end

@testset  "Network AC-PF PowerModels quadratic relaxations models" begin
    networks = [ PM.SOCWRForm,
                 PM.QCWRForm,
                 PM.QCWRTriForm,
                 ]
    systems = [c_sys5, c_sys14, c_sys14_dc]

    for network in networks, sys in systems
        @info "Testing construction of a $(network) network"
        ps_model = OperationModel(TestOptModel, network, sys; optimizer = ipopt_optimizer)
        construct_device!(ps_model, :Thermal, thermal_model);
        construct_device!(ps_model, :Load, load_model);
        construct_network!(ps_model, network);
        construct_device!(ps_model, :Line, line_model);
        construct_device!(ps_model, :DCLine, dc_line);
        @test !isnothing(ps_model.canonical.pm_model)
    end

end

@testset  "Network Unsupported Power Model Formulations" begin
    incompat_list = [PM.SDPWRMForm,
                    PM.SparseSDPWRMForm,
                    PM.SOCWRConicForm,
                    PM.SOCBFForm,
                    PM.SOCBFConicForm]

    for network in incompat_list
        ps_model = OperationModel(TestOptModel, network, c_sys5; optimizer = ipopt_optimizer)
        construct_device!(ps_model, :Thermal, thermal_model);
        construct_device!(ps_model, :Load, load_model);

        @test_throws ArgumentError construct_network!(ps_model, network);
    end

end