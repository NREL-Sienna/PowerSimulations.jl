thermal_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch)
load_model = DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad)
line_model = DeviceModel(PSY.Line, PSI.ACSeriesBranch)
transformer_model = DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch)
ttransformer_model = DeviceModel(PSY.TapTransformer, PSI.ACSeriesBranch)

@testset "Network Copper Plate" begin
    network = CopperPlatePowerModel
    systems = [c_sys5, c_sys14]
    parameters = [true, false]
    test_results = Dict{PSY.System, Vector{Int64}}(c_sys5 => [120, 120, 0, 0, 24],  
                                                   c_sys14 => [120, 120, 0, 0, 24])
    
    for (ix,sys) in enumerate(systems), p in parameters 
        buses = get_components(PSY.Bus, sys)
        base = sys.basepower
        ps_model = PSI._canonical_model_init(buses, base, OSQP_optimizer, network, time_steps; parameters = p)
        construct_device!(ps_model, thermal_model, network, sys, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, load_model, network, sys, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, line_model, network, sys, time_steps, Dates.Minute(5));
        construct_device!(ps_model, transformer_model, network, sys, time_steps, Dates.Minute(5));
        construct_device!(ps_model, ttransformer_model, network, sys, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, sys, time_steps; parameters = p);
        @test JuMP.num_variables(ps_model.JuMPmodel) == test_results[sys][1]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == test_results[sys][2]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == test_results[sys][3]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == test_results[sys][4]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == test_results[sys][5]

        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
    end
end

@testset "Network DC-PF with PTDF formulation" begin
    network = StandardPTDFForm
    systems = [c_sys5, c_sys14]
    parameters = [true, false]
    PTDF_ref = Dict{PSY.System, PSY.PTDF}(c_sys5 => PTDF5, c_sys14 => PTDF14)
    test_results = Dict{PSY.System, Vector{Int64}}(c_sys5 => [264, 120, 0, 0, 264],  
                                                    c_sys14 => [600, 120, 0, 0, 816])
    
    for (ix,sys) in enumerate(systems), p in parameters 
        buses = get_components(PSY.Bus, sys)
        base = sys.basepower
        ps_model = PSI._canonical_model_init(buses, base, OSQP_optimizer, network, time_steps; parameters = p)
        construct_device!(ps_model, thermal_model, network, sys, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, load_model, network, sys, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, line_model, network, sys, time_steps, Dates.Minute(5));
        construct_device!(ps_model, transformer_model, network, sys, time_steps, Dates.Minute(5));
        construct_device!(ps_model, ttransformer_model, network, sys, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, sys, time_steps; PTDF = PTDF_ref[sys], parameters = p);
        @test JuMP.num_variables(ps_model.JuMPmodel) == test_results[sys][1]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == test_results[sys][2]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == test_results[sys][3]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == test_results[sys][4]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == test_results[sys][5]

        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
    end

    #PTDF input Error testing
    ps_model = PSI._canonical_model_init(buses5, 100.0, GLPK_optimizer, network, time_steps)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5));
    @test_throws ArgumentError construct_network!(ps_model, network, c_sys5, time_steps)
end


@testset "Network DC lossless -PF network with PowerModels DCPlosslessForm" begin
    network = PM.DCPlosslessForm
    systems = [c_sys5, c_sys14]
    parameters = [true, false]
    test_results = Dict{PSY.System, Vector{Int64}}(c_sys5 => [384, 120, 144, 144, 288],  
                                                    c_sys14 => [936, 120, 480, 480, 840])
    
    for (ix,sys) in enumerate(systems), p in parameters 
        buses = get_components(PSY.Bus, sys)
        base = sys.basepower
        ps_model = PSI._canonical_model_init(buses, base, OSQP_optimizer, network, time_steps; parameters = p)
        construct_device!(ps_model, thermal_model, network, sys, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, load_model, network, sys, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, line_model, network, sys, time_steps, Dates.Minute(5));
        construct_device!(ps_model, transformer_model, network, sys, time_steps, Dates.Minute(5));
        construct_device!(ps_model, ttransformer_model, network, sys, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, sys, time_steps; parameters = p);
        @test JuMP.num_variables(ps_model.JuMPmodel) == test_results[sys][1]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == test_results[sys][2]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == test_results[sys][3]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == test_results[sys][4]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == test_results[sys][5]

        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
    end
   
end

@testset  "Network Solve AC-PF PowerModels StandardACPForm" begin
    network = PM.StandardACPForm
    systems = [c_sys5, c_sys14]
    parameters = [true, false]
    test_results = Dict{PSY.System, Vector{Int64}}(c_sys5 => [1056, 240, 144, 144, 264],  
                                                    c_sys14 => [2832, 240, 480, 480, 696])

    for (ix,sys) in enumerate(systems), p in parameters 
        buses = get_components(PSY.Bus, sys)
        base = sys.basepower
        ps_model = PSI._canonical_model_init(buses, base, ipopt_optimizer, network, time_steps; parameters = p)
        construct_device!(ps_model, thermal_model, network, sys, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, load_model, network, sys, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, line_model, network, sys, time_steps, Dates.Minute(5));
        construct_device!(ps_model, transformer_model, network, sys, time_steps, Dates.Minute(5));
        construct_device!(ps_model, ttransformer_model, network, sys, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, sys, time_steps; parameters = p);
        @test JuMP.num_variables(ps_model.JuMPmodel) == test_results[sys][1]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == test_results[sys][2]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == test_results[sys][3]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == test_results[sys][4]
        @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == test_results[sys][5]

        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
    end
end

@testset  "Network Solve AC-PF PowerModels linear approximation models" begin
    networks = [PM.DCPlosslessForm, PM.NFAForm]
    for network in networks
        @info "Testing construction of a $(network) network"
        ps_model = PSI._canonical_model_init(buses5, 100.0, GLPK_optimizer, network, time_steps)
        construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, c_sys5, time_steps);
        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

        ps_model = PSI._canonical_model_init(buses5, 100.0, GLPK_optimizer, network, time_steps; parameters = false)
        construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5); parameters = false)
        construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5); parameters = false)
        construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, c_sys5, time_steps; parameters = false)
        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

        #14 Bus Testing
        ps_model = PSI._canonical_model_init(buses14, 100.0, GLPK_optimizer, network, time_steps)
        construct_device!(ps_model, thermal_model, network, c_sys14, time_steps, Dates.Hour(1));
        construct_device!(ps_model, load_model, network, c_sys14, time_steps, Dates.Hour(1));
        construct_device!(ps_model, line_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_device!(ps_model, transformer_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_device!(ps_model, ttransformer_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, c_sys14, time_steps);
        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

        ps_model = PSI._canonical_model_init(buses14, 100.0, GLPK_optimizer, network, time_steps; parameters = false)
        construct_device!(ps_model, thermal_model, network, c_sys14, time_steps, Dates.Hour(1); parameters = false)
        construct_device!(ps_model, load_model, network, c_sys14, time_steps, Dates.Hour(1); parameters = false)
        construct_device!(ps_model, line_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_device!(ps_model, transformer_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_device!(ps_model, ttransformer_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, c_sys14, time_steps; parameters = false)
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

    for network in networks
        @info "Testing construction of a $(network) network"
        ps_model = PSI._canonical_model_init(buses5, 100.0, ipopt_optimizer, network, time_steps)
        construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, c_sys5, time_steps);
        @test !isnothing(ps_model.pm_model)
        #14 Bus Testing
        ps_model = PSI._canonical_model_init(buses14, 100.0, ipopt_optimizer, network, time_steps)
        construct_device!(ps_model, thermal_model, network, c_sys14, time_steps, Dates.Hour(1));
        construct_device!(ps_model, load_model, network, c_sys14, time_steps, Dates.Hour(1));
        construct_device!(ps_model, line_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_device!(ps_model, transformer_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_device!(ps_model, ttransformer_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, c_sys14, time_steps);
        @test !isnothing(ps_model.pm_model)
    end

end

@testset  "Network AC-PF PowerModels quadratic loss approximations models" begin
    networks = [PM.StandardDCPLLForm, PM.AbstractLPACCForm]

    for network in networks
        @info "Testing construction of a $(network) network"
        ps_model = PSI._canonical_model_init(buses5, 100.0, ipopt_optimizer, network, time_steps)
        construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, c_sys5, time_steps);
        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        #14 Bus Testing
        ps_model = PSI._canonical_model_init(buses14, 100.0, ipopt_optimizer, network, time_steps)
        construct_device!(ps_model, thermal_model, network, c_sys14, time_steps, Dates.Hour(1));
        construct_device!(ps_model, load_model, network, c_sys14, time_steps, Dates.Hour(1));
        construct_device!(ps_model, line_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_device!(ps_model, transformer_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_device!(ps_model, ttransformer_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, c_sys14, time_steps);
        JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
        JuMP.optimize!(ps_model.JuMPmodel)
        @test termination_status(ps_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
    end

end

@testset  "Network AC-PF PowerModels quadratic relaxations models" begin
    networks = [ PM.SOCWRForm,
                 PM.QCWRForm,
                 PM.QCWRTriForm,
                 ]

    for network in networks
        @info "Testing construction of a $(network) network"
        ps_model = PSI._canonical_model_init(buses5, 100.0, ipopt_optimizer, network, time_steps)
        construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, c_sys5, time_steps);
        @test !isnothing(ps_model.pm_model)
        #14 Bus Testing
        ps_model = PSI._canonical_model_init(buses14, 100.0, ipopt_optimizer, network, time_steps)
        construct_device!(ps_model, thermal_model, network, c_sys14, time_steps, Dates.Hour(1));
        construct_device!(ps_model, load_model, network, c_sys14, time_steps, Dates.Hour(1));
        construct_device!(ps_model, line_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_device!(ps_model, transformer_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_device!(ps_model, ttransformer_model, network, c_sys14, time_steps, Dates.Minute(5));
        construct_network!(ps_model, network, c_sys14, time_steps);
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
        ps_model = PSI._canonical_model_init(buses5, 100.0, ipopt_optimizer, network, time_steps)
        construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5));
        construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5));
        @test_throws ArgumentError construct_network!(ps_model, network, c_sys5, time_steps);
    end

end