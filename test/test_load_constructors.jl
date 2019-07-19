@testset "Load data misspecification" begin
    model = DeviceModel(PSY.InterruptibleLoad, PSI.DispatchablePowerLoad)
    warn_message = "The data doesn't devices of type InterruptibleLoad, consider changing the device models"
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Hour(1))
    @test_logs (:warn, warn_message) construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5);
    model = DeviceModel(PSY.PowerLoad, PSI.DispatchablePowerLoad)
    warn_message = "The Formulation DispatchablePowerLoad only applies to Controllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad"
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Hour(1))
    @test_logs (:warn, warn_message) construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5);
end

@testset "StaticPowerLoad" begin
    models = [PSI.StaticPowerLoad, PSI.DispatchablePowerLoad, PSI.InterruptiblePowerLoad]
    networks = [PM.DCPlosslessForm, PM.StandardACPForm]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PSY.PowerLoad, m)
        ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, model, n, c_sys5_il; parameters = p);
        @test (:params in keys(ps_model.JuMPmodel.ext)) == p
        @test JuMP.num_variables(ps_model.JuMPmodel) == 0
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    end
end

@testset "DispatchablePowerLoad DC- PF" begin
    models = [PSI.DispatchablePowerLoad]
    networks = [PM.DCPlosslessForm]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PSY.InterruptibleLoad, m)
        ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, model, n, c_sys5_il; parameters = p);
        @test (:params in keys(ps_model.JuMPmodel.ext)) == p
        @test JuMP.num_variables(ps_model.JuMPmodel) == 24
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == !p*24
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 24 - !p*24
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 24 - !p*24
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    end
end

@testset "DispatchablePowerLoad AC - PF" begin
    models = [PSI.DispatchablePowerLoad]
    networks = [PM.StandardACPForm]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PSY.InterruptibleLoad, m)
        ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, model, n, c_sys5_il; parameters = p);
        @test (:params in keys(ps_model.JuMPmodel.ext)) == p
        @test JuMP.num_variables(ps_model.JuMPmodel) == 48
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == !p*24
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 24 - !p*24
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 24 - !p*24
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 24
    end
end


@testset "InterruptiblePowerLoad DC- PF" begin
    models = [PSI.InterruptiblePowerLoad]
    networks = [PM.DCPlosslessForm]
    param_spec = [true, false]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PSY.InterruptibleLoad, m)
        ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, model, n, c_sys5_il; parameters = p);
        @test (:params in keys(ps_model.JuMPmodel.ext)) == p
        @test JuMP.num_variables(ps_model.JuMPmodel) == 48
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 0
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 24 + p*24
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 24
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
        @test  (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
    end
end

@testset "InterruptiblePowerLoad AC - PF" begin
    models = [PSI.InterruptiblePowerLoad]
    networks = [PM.StandardACPForm]
    param_spec = [true]
    for m in models, n in networks, p in param_spec
        model = DeviceModel(PSY.InterruptibleLoad, m)
        ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Hour(1); parameters = p);
        construct_device!(ps_model, model, n, c_sys5_il; parameters = p);
        @test (:params in keys(ps_model.JuMPmodel.ext)) == p
        @test JuMP.num_variables(ps_model.JuMPmodel) == 72
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 0
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 24 + p*24
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 24
        @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 24
        @test  (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
    end
end