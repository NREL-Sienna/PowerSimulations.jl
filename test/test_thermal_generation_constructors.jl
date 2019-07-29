@testset "ThermalGen data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't devices of type ThermalStandard, consider changing the device models"
    model = DeviceModel(ThermalStandard, PSI.ThermalUnitCommitment)
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5_re_only)
    @test_logs (:warn, warn_message) construct_device!(op_model, :Thermal, model);
end

################################### Unit Commitment tests #########################################
@testset "Thermal UC With DC - PF" begin
    bin_variable_names = [:ON_ThermalStandard,
                          :START_ThermalStandard,
                          :STOP_ThermalStandard]
    uc_constraint_names = [:ramp_up_ThermalStandard,
                           :ramp_down_ThermalStandard,
                           :duration_up_ThermalStandard,
                           :duration_down_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalUnitCommitment)

    @info "5-Bus testing"
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5)
    construct_device!(op_model, :Thermal, model);
    moi_tests(op_model, false, 480, 0, 624, 120, 120, true)
    psi_constraint_test(op_model, uc_constraint_names)
    psi_checkbinvar_test(op_model, bin_variable_names)
    psi_checkobjfun_test(op_model, GAEVF)

    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5; parameters = true)
    construct_device!(op_model, :Thermal, model);
    moi_tests(op_model, true, 480, 0, 456, 288, 120, true)
    psi_constraint_test(op_model, uc_constraint_names)
    psi_checkbinvar_test(op_model, bin_variable_names)
    psi_checkobjfun_test(op_model, GAEVF)

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5; parameters = p)
        construct_device!(op_model, :Thermal, model);
        moi_tests(op_model, p, 480, 0, 240, 120, 120, true)
        psi_constraint_test(op_model, uc_constraint_names)
        psi_checkbinvar_test(op_model, bin_variable_names)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end

@testset "Thermal UC With AC - PF" begin
    bin_variable_names = [:ON_ThermalStandard,
                          :START_ThermalStandard,
                          :STOP_ThermalStandard]
    uc_constraint_names = [:ramp_up_ThermalStandard,
                           :ramp_down_ThermalStandard,
                           :duration_up_ThermalStandard,
                           :duration_down_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalUnitCommitment)

    @info "5-Bus testing"
    op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys5)
    construct_device!(op_model, :Thermal, model);
    moi_tests(op_model, false, 600, 0, 744, 240, 120, true)
    psi_constraint_test(op_model, uc_constraint_names)
    psi_checkbinvar_test(op_model, bin_variable_names)
    psi_checkobjfun_test(op_model, GAEVF)

    op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys5; parameters = true)
    construct_device!(op_model, :Thermal, model);
    moi_tests(op_model, true, 600, 0, 576, 408, 120, true)
    psi_constraint_test(op_model, uc_constraint_names)
    psi_checkbinvar_test(op_model, bin_variable_names)
    psi_checkobjfun_test(op_model, GAEVF)

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys5; parameters = p)
        construct_device!(op_model, :Thermal, model);
        moi_tests(op_model, p, 0, 0, 360, 240, 120, true)
        psi_constraint_test(op_model, uc_constraint_names)
        psi_checkbinvar_test(op_model, bin_variable_names)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end

#=
################################### Basic Dispatch tests #########################################

@testset "Thermal Dispatch With DC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch)
    #5-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    #14-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}
end

@testset "Thermal Dispatch With AC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch)
    #5 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    #14 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}
end

################################### No Minimum Dispatch tests #########################################

@testset "Thermal Dispatch No-Minimum With DC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatchNoMin)
    #5 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:activerange_ThermalStandard]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}


    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:activerange_ThermalStandard]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    #14 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:activerange_ThermalStandard]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}


    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:activerange_ThermalStandard]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}
end

@testset "Thermal Dispatch No-Minimum With AC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatchNoMin)
    #5 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:activerange_ThermalStandard]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:activerange_ThermalStandard]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    #14 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:activerange_ThermalStandard]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:activerange_ThermalStandard]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}
end

################################### Ramp Limited Testing #########################################

@testset "Thermal Ramp Limited Dispatch With AC - PF" begin
    ramp_constraint_names = [:ramp_up_ThermalStandard, :ramp_down_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalRampLimited)
    #5 Bus Testing with 5 - Min simulation time
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    #5 Bus Testing with 1 Hour Simulation Time
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Hour(1))
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 48
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    #5 Bus Testing with 2 Hour Simulation Time
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Hour(2))
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    #14 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}
end

@testset "Thermal Ramp Limited Dispatch With DC - PF" begin
    ramp_constraint_names = [:ramp_up_ThermalStandard, :ramp_down_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalRampLimited)
    #5 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test !isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test !isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64, VariableRef}

    #14 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5))
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps, Dates.Minute(5); parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64, VariableRef}
end
=#
