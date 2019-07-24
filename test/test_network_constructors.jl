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

    for (ix, sys) in enumerate(systems), p in parameters
        buses = get_components(PSY.Bus, sys)
        bus_numbers = sort([b.number for b in buses])
        ps_model = PSI._canonical_model_init(bus_numbers, OSQP_optimizer, network, time_steps, Dates.Hour(1); parameters = p)
        construct_device!(ps_model, thermal_model, network, sys; parameters = p);
        construct_device!(ps_model, load_model, network, sys; parameters = p);
        construct_network!(ps_model, network, sys; parameters = p);
        construct_device!(ps_model, line_model, network, sys);
        construct_device!(ps_model, transformer_model, network, sys);
        construct_device!(ps_model, ttransformer_model, network, sys);
        construct_device!(ps_model, dc_line, network, sys);
        @test JuMP.num_variables(ps_model.JuMPmodel) == test_results[sys][1]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == test_results[sys][2]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == test_results[sys][3]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == test_results[sys][4]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == test_results[sys][5]

        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
    end
end

@testset "Network DC-PF with PTDF formulation" begin
    network = StandardPTDFForm
    systems = [c_sys5, c_sys14, c_sys14_dc]
    parameters = [true, false]
    PTDF_ref = Dict{PSY.System, PSY.PTDF}(c_sys5 => PTDF5, c_sys14 => PTDF14, c_sys14_dc => PTDF14_dc);
    test_results = Dict{PSY.System, Vector{Int64}}(c_sys5 => [264, 264, 0, 0, 264],
                                                    c_sys14 => [600, 600, 0, 0, 816],
                                                    c_sys14_dc => [552, 552, 0, 0, 768])

    for (ix, sys) in enumerate(systems), p in parameters
        buses = get_components(PSY.Bus, sys)
        bus_numbers = sort([b.number for b in buses])
        ps_model = PSI._canonical_model_init(bus_numbers, OSQP_optimizer, network, time_steps, Dates.Hour(1); parameters = p)
        construct_device!(ps_model, thermal_model, network, sys; parameters = p);
        construct_device!(ps_model, load_model, network, sys; parameters = p);
        construct_network!(ps_model, network, sys; PTDF = PTDF_ref[sys], parameters = p);
        construct_device!(ps_model, line_model, network, sys);
        construct_device!(ps_model, transformer_model, network, sys);
        construct_device!(ps_model, ttransformer_model, network, sys);
        construct_device!(ps_model, dc_line, network, sys);
        @test JuMP.num_variables(ps_model.JuMPmodel) == test_results[sys][1]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == test_results[sys][2]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == test_results[sys][3]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == test_results[sys][4]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == test_results[sys][5]

        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
    end

    #PTDF input Error testing
    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, network, time_steps, Dates.Hour(1))
    construct_device!(ps_model, thermal_model, network, c_sys5);
    construct_device!(ps_model, load_model, network, c_sys5);
    @test_throws ArgumentError construct_network!(ps_model, network, c_sys5)

end

@testset "Network DC lossless -PF network with PowerModels DCPlosslessForm" begin
    network = PM.DCPlosslessForm
    systems = [c_sys5, c_sys14, c_sys14_dc]
    parameters = [true, false]
    test_results = Dict{PSY.System, Vector{Int64}}(c_sys5 => [384, 264, 144, 144, 264],
                                                    c_sys14 => [936, 600, 480, 480, 816],
                                                    c_sys14_dc => [984, 600, 432, 432, 816])

    for (ix, sys) in enumerate(systems), p in parameters
        buses = get_components(PSY.Bus, sys)
        bus_numbers = sort([b.number for b in buses])
        ps_model = PSI._canonical_model_init(bus_numbers, OSQP_optimizer, network, time_steps, Dates.Hour(1); parameters = p)
        construct_device!(ps_model, thermal_model, network, sys; parameters = p);
        construct_device!(ps_model, load_model, network, sys; parameters = p);
        construct_network!(ps_model, network, sys; parameters = p);
        construct_device!(ps_model, line_model, network, sys);
        construct_device!(ps_model, transformer_model, network, sys);
        construct_device!(ps_model, ttransformer_model, network, sys);
        construct_device!(ps_model, dc_line, network, sys);

        @test JuMP.num_variables(ps_model.JuMPmodel) == test_results[sys][1]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == test_results[sys][2]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == test_results[sys][3]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == test_results[sys][4]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == test_results[sys][5]
        
        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
    end

end

@testset  "Network Solve AC-PF PowerModels StandardACPForm" begin
    network = PM.StandardACPForm
    systems = [c_sys5, c_sys14, c_sys14_dc]
    parameters = [true, false]
    test_results = Dict{PSY.System, Vector{Int64}}(c_sys5 => [1056, 240, 144, 144, 240],
                                                    c_sys14 => [2832, 240, 480, 480, 672],
                                                    c_sys14_dc => [2832, 240, 432, 432, 720])

    for (ix, sys) in enumerate(systems), p in parameters
        buses = get_components(PSY.Bus, sys)
        bus_numbers = sort([b.number for b in buses])
        ps_model = PSI._canonical_model_init(bus_numbers, ipopt_optimizer, network, time_steps, Dates.Hour(1); parameters = p)
        construct_device!(ps_model, thermal_model, network, sys; parameters = p);
        construct_device!(ps_model, load_model, network, sys; parameters = p);
        construct_network!(ps_model, network, sys; parameters = p);
        construct_device!(ps_model, line_model, network, sys);
        construct_device!(ps_model, transformer_model, network, sys);
        construct_device!(ps_model, ttransformer_model, network, sys);
        construct_device!(ps_model, dc_line, network, sys);
        @test JuMP.num_variables(ps_model.JuMPmodel) == test_results[sys][1]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == test_results[sys][2]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == test_results[sys][3]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == test_results[sys][4]
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == test_results[sys][5]

        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
    end
end

@testset  "Network Solve AC-PF PowerModels linear approximation models" begin
    networks = [PM.DCPlosslessForm, PM.NFAForm]
    systems = [c_sys5, c_sys14, c_sys14_dc]
    p = true
    for network in networks, sys in systems
        @info "Testing construction of a $(network) network"
        buses = get_components(PSY.Bus, sys)
        bus_numbers = sort([b.number for b in buses])
        ps_model = PSI._canonical_model_init(bus_numbers, GLPK_optimizer, network, time_steps, Dates.Hour(1); parameters = p)
        construct_device!(ps_model, thermal_model, network, sys; parameters = p)
        construct_device!(ps_model, load_model, network, sys; parameters = p)
        construct_network!(ps_model, network, sys; parameters = p)
        construct_device!(ps_model, line_model, network, sys);
        construct_device!(ps_model, dc_line, network, sys);
        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
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
        buses = get_components(PSY.Bus, sys)
        bus_numbers = sort([b.number for b in buses])
        ps_model = PSI._canonical_model_init(bus_numbers, ipopt_optimizer, network, time_steps, Dates.Hour(1))
        construct_device!(ps_model, thermal_model, network, sys);
        construct_device!(ps_model, load_model, network, sys);
        construct_network!(ps_model, network, sys);
        construct_device!(ps_model, line_model, network, sys);
        @test !isnothing(ps_model.pm_model)
    end

end

@testset  "Network AC-PF PowerModels quadratic loss approximations models" begin
    networks = [PM.StandardDCPLLForm, PM.AbstractLPACCForm]
    systems = [c_sys5, c_sys14, c_sys14_dc]

    for network in networks, sys in systems
        @info "Testing construction of a $(network) network"
        buses = get_components(PSY.Bus, sys)
        bus_numbers = sort([b.number for b in buses])
        ps_model = PSI._canonical_model_init(bus_numbers, ipopt_optimizer, network, time_steps, Dates.Hour(1))
        construct_device!(ps_model, thermal_model, network, sys);
        construct_device!(ps_model, load_model, network, sys);
        construct_network!(ps_model, network, sys);
        construct_device!(ps_model, line_model, network, sys);
        @test !isnothing(ps_model.pm_model)
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
        buses = get_components(PSY.Bus, sys)
        bus_numbers = sort([b.number for b in buses])
        ps_model = PSI._canonical_model_init(bus_numbers, ipopt_optimizer, network, time_steps, Dates.Hour(1))
        construct_device!(ps_model, thermal_model, network, sys);
        construct_device!(ps_model, load_model, network, sys);
        construct_network!(ps_model, network, sys);
        construct_device!(ps_model, line_model, network, sys);
        @test !isnothing(ps_model.pm_model)
    end

end

@testset  "Network Unsupported Power Model Formulations" begin
    incompat_list = [PM.SDPWRMForm,
                    PM.SparseSDPWRMForm,
                    PM.SOCWRConicForm,
                    PM.SOCBFForm,
                    PM.SOCBFConicForm]

    for network in incompat_list
        ps_model = PSI._canonical_model_init(bus_numbers5, ipopt_optimizer, network, time_steps, Dates.Hour(1))
        construct_device!(ps_model, thermal_model, network, c_sys5);
        construct_device!(ps_model, load_model, network, c_sys5);
        @test_throws ArgumentError construct_network!(ps_model, network, c_sys5);
    end

end