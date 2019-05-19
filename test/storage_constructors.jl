@testset "Storage Basic Storage With DC - PF" begin
    model = DeviceModel(PSY.GenericBattery, PSI.BookKeeping)
    network = PM.DCPlosslessForm
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, network, time_steps)
    construct_device!(ps_model, model, network, c_sys5_bat, time_steps, Dates.Hour(1));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24
end

@testset "Storage Basic Storage With AC - PF" begin
    model = DeviceModel(PSY.GenericBattery, PSI.BookKeeping)
    network = PM.StandardACPForm
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, network, c_sys5_bat, time_steps, Dates.Hour(1));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 96
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 96
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24
end

@testset "Storage with Reservation DC - PF" begin
model = DeviceModel(PSY.GenericBattery, PSI.BookKeepingwReservation)
    network = PM.DCPlosslessForm
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, network, time_steps)
    construct_device!(ps_model, model, network, c_sys5_bat, time_steps, Dates.Hour(1));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 96
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 48
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 48
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 24
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24
    @test (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
end

@testset "Storage with Reservation With AC - PF" begin
    model = DeviceModel(PSY.GenericBattery, PSI.BookKeepingwReservation)
    network = PM.StandardACPForm
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, network, time_steps)
    construct_device!(ps_model, model, network, c_sys5_bat, time_steps, Dates.Hour(1));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 48
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 48
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 48
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24
    @test (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
end