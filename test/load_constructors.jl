@testset "Interruptible DCPLossLess" begin
    ps_model = PSI._canonical_model_init(length(sys5b_uc.buses), nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.InterruptiblePowerLoad, PM.DCPlosslessForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No parameters testing
    ps_model = PSI._canonical_model_init(length(sys5b_uc.buses), nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.InterruptiblePowerLoad, PM.DCPlosslessForm, sys5b, time_range; parameters = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Interruptible ACP" begin
    ps_model = PSI._canonical_model_init(length(sys5b_uc.buses), nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.InterruptiblePowerLoad, PM.StandardACPForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(length(sys5b_uc.buses), nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.InterruptiblePowerLoad, PM.StandardACPForm, sys5b, time_range; parameters = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Static Load DCPLossLess" begin
    ps_model = PSI._canonical_model_init(length(sys5b_uc.buses), nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.DCPlosslessForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(length(sys5b_uc.buses), nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.DCPlosslessForm, sys5b, time_range; parameters = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Static Load ACP" begin
    ps_model = PSI._canonical_model_init(length(sys5b_uc.buses), nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.StandardACPForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(length(sys5b_uc.buses), nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.StandardACPForm, sys5b, time_range; parameters = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end