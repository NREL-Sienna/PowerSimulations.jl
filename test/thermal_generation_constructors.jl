@testset "testing UC With DC - PF" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalUnitCommitment, PM.DCPlosslessForm, sys5b_uc, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 504
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
end

@testset "testing UC With AC - PF" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalUnitCommitment, PM.StandardACPForm, sys5b_uc, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 624
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
end

@testset "testing Dispatch With DC - PF" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PM.DCPlosslessForm, sys5b_uc, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    end

@testset "testing Dispatch With AC - PF" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PM.StandardACPForm, sys5b_uc, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    end

@testset "testing Dispatch No-Minimum With DC - PF" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatchNoMin, PM.DCPlosslessForm, sys5b_uc, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "testing Dispatch No-Mini beginmum With AC - PF" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatchNoMin, PM.StandardACPForm, sys5b_uc, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "testing Dispatch No-Mini beginmum With DC - PF" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatchNoMin, PM.DCPlosslessForm, sys5b_uc, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "testing Ramp Limited Dis beginpatch With AC - PF" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalRampLimited, PM.StandardACPForm, sys5b_uc, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "testing Ramp Limited Dis beginpatch With DC - PF" begin
    ps_model = PSI._ps_model_init(sys5b_uc, nothing, PM.AbstractPowerFormulation, sys5b_uc.time_periods)  
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalRampLimited, PM.DCPlosslessForm, sys5b_uc, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end
