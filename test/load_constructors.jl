@testset "Load data misspecification" begin
    model = DeviceModel(PSY.InterruptibleLoad, PSI.DispatchablePowerLoad)
    warn_message = "The data doesn't devices of type InterruptibleLoad, consider changing the device models"
    ps_model = PSI._canonical_model_init(buses5, 100.0, nothing, PM.AbstractPowerFormulation, time_steps)
    @test_logs (:warn, warn_message) construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Hour(1));
    model = DeviceModel(PSY.PowerLoad, PSI.DispatchablePowerLoad)
    warn_message = "The Formulation PowerSimulations.DispatchablePowerLoad only applies to Controllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad"
    ps_model = PSI._canonical_model_init(buses5, 100.0, nothing, PM.AbstractPowerFormulation, time_steps)
    @test_logs (:warn, warn_message) construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Hour(1));
end

@testset "Load Dispatchable DCPLossLess" begin
    model = DeviceModel(PSY.PowerLoad, PSI.DispatchablePowerLoad)
    ps_model = PSI._canonical_model_init(buses5, 100.0, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Hour(1));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No parameters testing
    ps_model = PSI._canonical_model_init(buses5, 100.0, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false);
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Hour(1); parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Load Dispatchable ACP" begin
    model = DeviceModel(PSY.PowerLoad, PSI.DispatchablePowerLoad)
    ps_model = PSI._canonical_model_init(buses5, 100.0, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Hour(1));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(buses5, 100.0, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false);
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Hour(1); parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Load Static DCPLossLess" begin
    model = DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad)
    ps_model = PSI._canonical_model_init(buses5, 100.0, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Hour(1));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(buses5, 100.0, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false);
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Hour(1); parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Load Static ACP" begin
    model = DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad)
    ps_model = PSI._canonical_model_init(buses5, 100.0, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Hour(1));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(buses5, 100.0, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false);
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Hour(1); parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end