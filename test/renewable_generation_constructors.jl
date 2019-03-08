@testset "Renewable Testing" begin
    ps_model = PSI._canonical_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.RenewableGen, PSI.RenewableFullDispatch, PM.DCPlosslessForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

#@testset "Renewable Testing" begin
#ps_model = PSI._canonical_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
#PSI.construct_device!(ps_model, PSY.RenewableGen, PSI.RenewableFullDispatch, PM.StandardACPForm, sys5b, time_range);
#end

@testset "Renewable Testing" begin
    ps_model = PSI._canonical_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.RenewableGen, PSI.RenewableConstantPowerFactor, PM.DCPlosslessForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Renewable Testing" begin
    ps_model = PSI._canonical_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.RenewableGen, PSI.RenewableConstantPowerFactor, PM.StandardACPForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 72
end

@testset "Renewable Testing" begin
    ps_model = PSI._canonical_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.RenewableGen, PSI.RenewableFixed, PM.DCPlosslessForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Renewable Testing" begin
    ps_model = PSI._canonical_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.RenewableGen, PSI.RenewableFixed, PM.StandardACPForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end