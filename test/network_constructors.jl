@testset "testing copper plate network construction" begin
    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, PM.AbstractPowerFormulation, 1:sys5b.time_periods)
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PSI.CopperPlatePowerModel, sys5b, time_range);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PSI.CopperPlatePowerModel, sys5b, time_range);
    PSI.construct_network!(ps_model, PSI.CopperPlatePowerModel, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)
    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, PM.AbstractPowerFormulation, 1:sys5b.time_periods; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PSI.CopperPlatePowerModel, sys5b, time_range; parameters = false);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PSI.CopperPlatePowerModel, sys5b, time_range; parameters = false);
    PSI.construct_network!(ps_model, PSI.CopperPlatePowerModel, sys5b, time_range; parameters = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)
    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
end

@testset "testing DC-PF with PTDF formulation" begin
    PTDF, A = PowerSystems.buildptdf(branches5, nodes5)
    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, PM.AbstractPowerFormulation, 1:sys5b.time_periods)
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PSI.StandardPTDFForm, sys5b, time_range);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PSI.StandardPTDFForm, sys5b, time_range);
    PSI.construct_network!(ps_model, PSI.StandardPTDFForm, sys5b, time_range; PTDF = PTDF)
    PSI.construct_device!(ps_model, PSY.Branch, PSI.SeriesLine, PSI.StandardPTDFForm, sys5b, time_range)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 264
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 264
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, PM.AbstractPowerFormulation, 1:sys5b.time_periods; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PSI.StandardPTDFForm, sys5b, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PSI.StandardPTDFForm, sys5b, time_range; parameters = false)
    PSI.construct_network!(ps_model, PSI.StandardPTDFForm, sys5b, time_range; PTDF = PTDF, parameters = false)
    PSI.construct_device!(ps_model, PSY.Branch, PSI.SeriesLine, PSI.StandardPTDFForm, sys5b, time_range; parameters = false)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 264
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 264
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
end

 @testset "PTDF ArgumentError" begin
    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, PM.AbstractPowerFormulation, 1:sys5b.time_periods)
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PSI.StandardPTDFForm, sys5b, time_range);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PSI.StandardPTDFForm, sys5b, time_range);
    @test_throws ArgumentError PSI.construct_network!(ps_model, PSI.StandardPTDFForm, sys5b, time_range)
end

@testset "testing DC-PF network construction" begin
    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, PM.AbstractPowerFormulation, 1:sys5b.time_periods)
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PM.DCPlosslessForm, sys5b, time_range);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.DCPlosslessForm, sys5b, time_range);
    PSI.construct_network!(ps_model, PM.DCPlosslessForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 384
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 288

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, PM.AbstractPowerFormulation, 1:sys5b.time_periods; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PM.DCPlosslessForm, sys5b, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.DCPlosslessForm, sys5b, time_range; parameters = false)
    PSI.construct_network!(ps_model, PM.DCPlosslessForm, sys5b, time_range; parameters = false)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 384
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 288

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
end

@testset  "testing AC-PF network construction" begin
    ps_model = PSI._canonical_model_init(bus_numbers5, ipopt_optimizer, PM.AbstractPowerFormulation, 1:sys5b.time_periods)
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PM.StandardACPForm, sys5b, time_range);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.StandardACPForm, sys5b, time_range);
    PSI.construct_network!(ps_model, PM.StandardACPForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 1056
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]

    ps_model = PSI._canonical_model_init(bus_numbers5, ipopt_optimizer, PM.AbstractPowerFormulation, 1:sys5b.time_periods; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PM.StandardACPForm, sys5b, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.StandardACPForm, sys5b, time_range; parameters = false)
    PSI.construct_network!(ps_model, PM.StandardACPForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 1056
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
end
