@testset "Load Constructors" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.InterruptiblePowerLoad, PM.DCPlosslessForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Load Constructors" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.InterruptiblePowerLoad, PM.StandardACPForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Load Constructors" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.DCPlosslessForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Load Constructors" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.StandardACPForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end