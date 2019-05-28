thermal_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch)
load_model = DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad)
line_model = DeviceModel(PSY.Line, PSI.ACSeriesBranch)
transformer_model = DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch)
ttransformer_model = DeviceModel(PSY.TapTransformer, PSI.ACSeriesBranch)
buses5 = PSY.get_components(PSY.Bus, c_sys5)
buses14 = PSY.get_components(PSY.Bus, c_sys14)

@testset "Network Copper Plate" begin
    #5- Bus - Testing
    network = PSI.CopperPlatePowerModel
    ps_model = PSI._canonical_model_init(buses5, 100.0, GLPK_optimizer, network, time_steps)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys5, time_steps);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)
    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(buses5, 100.0, GLPK_optimizer, network, time_steps; parameters = false)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5); parameters = false);
    construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5); parameters = false);
    construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys5, time_steps; parameters = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)
    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    #14- Bus - Testing
    ps_model = PSI._canonical_model_init(buses14, 100.0, GLPK_optimizer, network, time_steps)
    construct_device!(ps_model, thermal_model, network, c_sys14, time_steps, Dates.Hour(1));
    construct_device!(ps_model, load_model, network, c_sys14, time_steps, Dates.Hour(1));
    construct_device!(ps_model, line_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_device!(ps_model, transformer_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_device!(ps_model, ttransformer_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys14, time_steps);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)
    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(buses14, 100.0, GLPK_optimizer, network, time_steps; parameters = false)
    construct_device!(ps_model, thermal_model, network, c_sys14, time_steps, Dates.Hour(1); parameters = false);
    construct_device!(ps_model, load_model, network, c_sys14, time_steps, Dates.Hour(1); parameters = false);
    construct_device!(ps_model, line_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_device!(ps_model, transformer_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_device!(ps_model, ttransformer_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys14, time_steps; parameters = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)
    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
end

@testset "Network DC-PF with PTDF formulation" begin
    #5-Bus testing
    network = PSI.StandardPTDFForm
    ps_model = PSI._canonical_model_init(buses5, 100.0, GLPK_optimizer, network, time_steps)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys5, time_steps; PTDF = PTDF5)
    construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 264
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(buses5, 100.0, GLPK_optimizer, network, time_steps; parameters = false)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys5, time_steps; PTDF = PTDF5, parameters = false)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 264
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

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
    construct_network!(ps_model, network, c_sys14, time_steps; PTDF = PTDF14)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 816

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(buses14, 100.0, GLPK_optimizer, network, time_steps; parameters = false)
    construct_device!(ps_model, thermal_model, network, c_sys14, time_steps, Dates.Hour(1); parameters = false)
    construct_device!(ps_model, load_model, network, c_sys14, time_steps, Dates.Hour(1); parameters = false)
    construct_device!(ps_model, line_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_device!(ps_model, transformer_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_device!(ps_model, ttransformer_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys14, time_steps; PTDF = PTDF14, parameters = false)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 816

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    #PTDF input Error testing
    ps_model = PSI._canonical_model_init(buses5, 100.0, GLPK_optimizer, network, time_steps)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5));
    @test_throws ArgumentError construct_network!(ps_model, network, c_sys5, time_steps)
end


@testset "Network DC-PF network with PowerModels DCPlosslessForm" begin
    #5 Bus Testing
    network = PM.DCPlosslessForm
    ps_model = PSI._canonical_model_init(buses5, 100.0, GLPK_optimizer, network, time_steps)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys5, time_steps);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 384
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 288

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(buses5, 100.0, GLPK_optimizer, network, time_steps; parameters = false)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys5, time_steps; parameters = false)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 384
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 288

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
    @test JuMP.num_variables(ps_model.JuMPmodel) == 936
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 840

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
    @test JuMP.num_variables(ps_model.JuMPmodel) == 936
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 840

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
end

@testset  "Network Solve AC-PF PowerModels StandardACPForm" begin
    network = PM.StandardACPForm
    ps_model = PSI._canonical_model_init(buses5, 100.0, ipopt_optimizer, network, time_steps)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys5, time_steps);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 1056
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]

    ps_model = PSI._canonical_model_init(buses5, 100.0, ipopt_optimizer, network, time_steps; parameters = false)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, load_model, network, c_sys5, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, line_model, network, c_sys5, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys5, time_steps);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 1056
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

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
    @test JuMP.num_variables(ps_model.JuMPmodel) == 2832
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 696

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]

    ps_model = PSI._canonical_model_init(buses14, 100.0, ipopt_optimizer, network, time_steps; parameters = false)
    construct_device!(ps_model, thermal_model, network, c_sys14, time_steps, Dates.Hour(1); parameters = false)
    construct_device!(ps_model, load_model, network, c_sys14, time_steps, Dates.Hour(1); parameters = false)
    construct_device!(ps_model, line_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_device!(ps_model, transformer_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_device!(ps_model, ttransformer_model, network, c_sys14, time_steps, Dates.Minute(5));
    construct_network!(ps_model, network, c_sys14, time_steps);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 2832
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 696

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
end

@testset  "Network Solve AC-PF PowerModels linear approximation models" begin
    networks = [PM.DCPlosslessForm, PM.NFAForm]
    for network in networks
        @info "Testing $(network)"
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
        @info "Testing $(network)"
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

@testset  "Network AC-PF PowerModels quadratic approximations models" begin
    networks = [PM.StandardDCPLLForm, PM.AbstractLPACCForm]

    for network in networks
        @info "Testing $(network)"
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
        @info "Testing $(network)"
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