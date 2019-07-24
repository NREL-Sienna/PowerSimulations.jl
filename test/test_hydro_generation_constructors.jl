@testset "Renewable data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't devices of type HydroDispatch, consider changing the device models"
    model = DeviceModel(PSY.HydroDispatch, PSI.HydroDispatchRunOfRiver)
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    @test_logs (:warn, warn_message) construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5_hy; parameters = true);
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    @test_logs (:warn, warn_message) construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14; parameters = true);
end


@testset "Hydro DCPLossLess FixedOutput" begin
    model = model = DeviceModel(PSY.HydroFix, PSI.HydroFixed)
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5_hy);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5_hy; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    # No Forecast Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5_hy; forecast = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    # No Forecast - No Parameters Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5_hy; parameters = false, forecast = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
end

#=
@testset " Hydro Tests" begin
    PSI.activepower_variables(ps_model, generators_hg, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.DCPlosslessForm, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.StandardACPForm, 1:24)
    PSI.reactivepower_variables(ps_model, generators_hg, 1:24)
    PSI.reactivepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.StandardACPForm, 1:24)
end

@testset " Hydro Tests" begin
    ps_model = PSI._canonical_model_init(length(sys5b.buses), nothing, PM.AbstractPowerFormulation, sys5b.time_periods)
    PSI.activepower_variables(ps_model, generators_hg, 1:24)
    PSI.commitment_variables(ps_model, generators_hg, 1:24);
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.DCPlosslessForm, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.StandardACPForm, 1:24)
    PSI.reactivepower_variables(ps_model, generators_hg, 1:24)
    PSI.reactivepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.StandardACPForm, 1:24)
end
=#