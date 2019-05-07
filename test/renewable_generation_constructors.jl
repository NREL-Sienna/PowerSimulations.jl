@testset "Renewable DCPLossLess FullDispatch" begin
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.RenewableCurtailment, PSI.RenewableFullDispatch, PM.DCPlosslessForm, c_sys5_re, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.RenewableCurtailment, PSI.RenewableFullDispatch, PM.DCPlosslessForm, c_sys5_re, time_range; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

#@testset "Renewable Testing" begin
#ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
#PSI.construct_device!(ps_model, PSY.RenewableCurtailment, PSI.RenewableFullDispatch, PM.StandardACPForm, c_sys5_re, time_range);
#end

@testset "Renewable DCPLossLess ConstantPowerFactor" begin
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.RenewableCurtailment, PSI.RenewableConstantPowerFactor, PM.DCPlosslessForm, c_sys5_re, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.RenewableCurtailment, PSI.RenewableConstantPowerFactor, PM.DCPlosslessForm, c_sys5_re, time_range; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Renewable ACP ConstantPowerFactor" begin
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.RenewableCurtailment, PSI.RenewableConstantPowerFactor, PM.StandardACPForm, c_sys5_re, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 72
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.RenewableCurtailment, PSI.RenewableConstantPowerFactor, PM.StandardACPForm, c_sys5_re, time_range; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 144
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 72
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 72
end

@testset "Renewable DCPLossLess FixedOutput" begin
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.RenewableCurtailment, PSI.RenewableFixed, PM.DCPlosslessForm, c_sys5_re, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.RenewableCurtailment, PSI.RenewableFixed, PM.DCPlosslessForm, c_sys5_re, time_range; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Renewable ACP FixedOutput" begin
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.RenewableCurtailment, PSI.RenewableFixed, PM.StandardACPForm, c_sys5_re, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    # No Parameters Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.RenewableCurtailment, PSI.RenewableFixed, PM.StandardACPForm, c_sys5_re, time_range; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end