################################### Unit Commitment tests #########################################
@testset "Thermal UC With DC - PF" begin
    variable_names = [:ONth_StandardThermal, :STARTth_StandardThermal, :STOPth_StandardThermal]
    uc_constraint_names = [:ramp_StandardThermal_up, :ramp_StandardThermal_down, :duration_StandardThermal_up, :duration_StandardThermal_down]
    model = DeviceModel(PSY.StandardThermal, PSI.ThermalUnitCommitment)
    #5-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Minute(5); parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 504
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
    @test  (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    for con in uc_constraint_names
        @test !isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps; parameters = true)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Minute(5); parameters = true);
    @test (:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 504
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
    @test  (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    for con in uc_constraint_names
        @test !isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    #14-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14, time_steps, Dates.Minute(5); parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
    @test  (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    for con in uc_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps; parameters = true)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14, time_steps, Dates.Minute(5); parameters = true);
    @test (:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
    @test  (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    for con in uc_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}
end

@testset "Thermal UC With AC - PF" begin
    variable_names = [:ONth_StandardThermal, :STARTth_StandardThermal, :STOPth_StandardThermal]
    uc_constraint_names = [:ramp_StandardThermal_up, :ramp_StandardThermal_down, :duration_StandardThermall_up, :duration_StandardThermal_down]
    model = DeviceModel(PSY.StandardThermal, PSI.ThermalUnitCommitment)
    #5-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Minute(5); parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 624
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
    @test  (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps; parameters = true)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Minute(5); parameters = true);
    @test (:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 624
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
    @test  (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    #14-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14, time_steps, Dates.Minute(5); parameters = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
    @test  (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    for con in uc_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps; parameters = true)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14, time_steps, Dates.Minute(5); parameters = true);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
    @test  (VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel)
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    for con in uc_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}
end


################################### Basic Dispatch tests #########################################

@testset "Thermal Dispatch With DC - PF" begin
    model = DeviceModel(PSY.StandardThermal, PSI.ThermalDispatch)
    #5-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Minute(5); parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    #14-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14, time_steps, Dates.Minute(5); parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}
end

@testset "Thermal Dispatch With AC - PF" begin
    model = DeviceModel(PSY.StandardThermal, PSI.ThermalDispatch)
    #5 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Minute(5); parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    #14 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14, time_steps, Dates.Minute(5); parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}
end

################################### No Minimum Dispatch tests #########################################

@testset "Thermal Dispatch No-Minimum With DC - PF" begin
    model = DeviceModel(PSY.StandardThermal, PSI.ThermalDispatchNoMin)
    #5 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:active_range_StandardThermal]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}


    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Minute(5); parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:active_range_StandardThermal]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    #14 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:active_range_StandardThermal]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}


    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14, time_steps, Dates.Minute(5); parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:active_range_StandardThermal]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}
end

@testset "Thermal Dispatch No-Minimum With AC - PF" begin
    model = DeviceModel(PSY.StandardThermal, PSI.ThermalDispatchNoMin)
    #5 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:active_range_StandardThermal]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Minute(5); parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:active_range_StandardThermal]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    #14 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:active_range_StandardThermal]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14, time_steps, Dates.Minute(5); parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:active_range_StandardThermal]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}
end

################################### Ramp Limited Testing #########################################

@testset "Thermal Ramp Limited Dispatch With AC - PF" begin
    ramp_constraint_names = [:ramp_StandardThermal_up, :ramp_StandardThermal_down]
    model = DeviceModel(PSY.StandardThermal, PSI.ThermalRampLimited)
    #5 Bus Testing with 5 - Min simulation time
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    #5 Bus Testing with 1 Hour Simulation Time
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Hour(1));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 48
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    #5 Bus Testing with 2 Hour Simulation Time
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Hour(2));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys5, time_steps, Dates.Minute(5); parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    #14 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.StandardACPForm, c_sys14, time_steps, Dates.Minute(5); parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}
end

@testset "Thermal Ramp Limited Dispatch With DC - PF" begin
    ramp_constraint_names = [:ramp_StandardThermal_up, :ramp_StandardThermal_down]
    model = DeviceModel(PSY.StandardThermal, PSI.ThermalRampLimited)
    #5 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test !isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys5, time_steps, Dates.Minute(5); parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test !isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericAffExpr{Float64,VariableRef}

    #14 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14, time_steps, Dates.Minute(5));
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_steps; parameters = false)
    construct_device!(ps_model, model, PM.DCPlosslessForm, c_sys14, time_steps, Dates.Minute(5); parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test  !((VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(ps_model.JuMPmodel))
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == JuMP.GenericQuadExpr{Float64,VariableRef}
end
