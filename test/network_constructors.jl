thermal_model = DeviceModel(PSY.ThermalDispatch, PSI.ThermalDispatch)
load_model = DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad)
line_model = DeviceModel(PSY.Line, PSI.ACSeriesBranch)
transformer_model = DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch)

@testset "Network copper plate" begin
    #5- Bus - Testing
    network = PSI.CopperPlatePowerModel
    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, network, time_range)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_range);
    construct_device!(ps_model, load_model, network, c_sys5, time_range);
    construct_network!(ps_model, network, c_sys5, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)
    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, PM.AbstractPowerFormulation, time_range; parameters = false)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_range; parameters = false);
    construct_device!(ps_model, load_model, network, c_sys5, time_range; parameters = false);
    construct_network!(ps_model, network, c_sys5, time_range; parameters = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)
    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    #14- Bus - Testing
    ps_model = PSI._canonical_model_init(bus_numbers14, GLPK_optimizer, PM.AbstractPowerFormulation, time_range)
    construct_device!(ps_model, thermal_model, network, c_sys14, time_range);
    construct_device!(ps_model, load_model, network, c_sys14, time_range);
    construct_network!(ps_model, network, c_sys14, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)
    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(bus_numbers14, GLPK_optimizer, PM.AbstractPowerFormulation, time_range; parameters = false)
    construct_device!(ps_model, thermal_model, network, c_sys14, time_range; parameters = false);
    construct_device!(ps_model, load_model, network, c_sys14, time_range; parameters = false);
    construct_network!(ps_model, network, c_sys14, time_range; parameters = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)
    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
end

@testset "Network DC-PF with PTDF formulation 5" begin
    #5-Bus testing
    network = PSI.StandardPTDFForm
    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, network, time_range)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_range);
    construct_device!(ps_model, load_model, network, c_sys5, time_range);
    construct_network!(ps_model, network, c_sys5, time_range; PTDF = PTDF5)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 264
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, network, time_range; parameters = false)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_range; parameters = false)
    construct_device!(ps_model, load_model, network, c_sys5, time_range; parameters = false)
    construct_network!(ps_model, network, c_sys5, time_range; PTDF = PTDF5, parameters = false)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 264
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    #14 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers14, GLPK_optimizer, PM.AbstractPowerFormulation, time_range)
    construct_device!(ps_model, thermal_model, network, c_sys14, time_range);
    construct_device!(ps_model, load_model, network, c_sys14, time_range);
    construct_network!(ps_model, network, c_sys14, time_range; PTDF = PTDF14)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 816

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(bus_numbers14, GLPK_optimizer, PM.AbstractPowerFormulation, time_range; parameters = false)
    construct_device!(ps_model, thermal_model, network, c_sys14, time_range; parameters = false)
    construct_device!(ps_model, load_model, network, c_sys14, time_range; parameters = false)
    construct_network!(ps_model, network, c_sys14, time_range; PTDF = PTDF14, parameters = false)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 816

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL


    #PTDF input Error testing
    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, PM.AbstractPowerFormulation, time_range)
    construct_device!(ps_model, thermal_model, network, c_sys5, time_range);
    construct_device!(ps_model, load_model, network, c_sys5, time_range);
    @test_throws ArgumentError construct_network!(ps_model, network, c_sys5, time_range)
end

#=
@testset "Network DC-PF network" begin
    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, PM.AbstractPowerFormulation, time_range)
    construct_device!(ps_model, thermal_model, PM.DCPlosslessForm, c_sys5, time_range);
    construct_device!(ps_model, load_model, PM.DCPlosslessForm, c_sys5, time_range);
    construct_network!(ps_model, PM.DCPlosslessForm, c_sys5, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 384
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 288

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL

    ps_model = PSI._canonical_model_init(bus_numbers5, GLPK_optimizer, PM.AbstractPowerFormulation, time_range; parameters = false)
    construct_device!(ps_model, thermal_model, PM.DCPlosslessForm, c_sys5, time_range; parameters = false)
    construct_device!(ps_model, load_model, PM.DCPlosslessForm, c_sys5, time_range; parameters = false)
    construct_network!(ps_model, PM.DCPlosslessForm, c_sys5, time_range; parameters = false)
    @test JuMP.num_variables(ps_model.JuMPmodel) == 384
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 288

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
end

@testset  "Network AC-PF network construction" begin
    ps_model = PSI._canonical_model_init(bus_numbers5, ipopt_optimizer, PM.AbstractPowerFormulation, time_range)
    construct_device!(ps_model, thermal_model, PM.StandardACPForm, c_sys5, time_range);
    construct_device!(ps_model, load_model, PM.StandardACPForm, c_sys5, time_range);
    construct_network!(ps_model, PM.StandardACPForm, c_sys5, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 1056
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]

    ps_model = PSI._canonical_model_init(bus_numbers5, ipopt_optimizer, PM.AbstractPowerFormulation, time_range; parameters = false)
    construct_device!(ps_model, thermal_model, PM.StandardACPForm, c_sys5, time_range; parameters = false)
    construct_device!(ps_model, load_model, PM.StandardACPForm, c_sys5, time_range; parameters = false)
    construct_network!(ps_model, PM.StandardACPForm, c_sys5, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 1056
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    @test termination_status(ps_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
end
=#