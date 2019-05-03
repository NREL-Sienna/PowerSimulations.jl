@testset "UC With DC - PF" begin
    variable_names = [:on_th, :start_th, :stop_th]
    uc_constraint_names = [:ramp_thermal_up, :ramp_thermal_down, :duration_thermal_up, :duration_thermal_down]
    #5-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalUnitCommitment, PM.DCPlosslessForm, c_sys5, time_range; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 504
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 96
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    for con in uc_constraint_names
        @test !isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = true)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalUnitCommitment, PM.DCPlosslessForm, c_sys5, time_range; parameters = true);
    @test (:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 504
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 96
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    for con in uc_constraint_names
        @test !isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    #14-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalUnitCommitment, PM.DCPlosslessForm, c_sys14, time_range; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    for con in uc_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)  
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range; parameters = true)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalUnitCommitment, PM.DCPlosslessForm, c_sys14, time_range; parameters = true);
    @test (:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 480
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    for con in uc_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)  
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef}
end

@testset "UC With AC - PF" begin
    variable_names = [:on_th, :start_th, :stop_th]
    uc_constraint_names = [:ramp_thermal_up, :ramp_thermal_down, :duration_thermal_up, :duration_thermal_down]
    #5-Bus testing    
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalUnitCommitment, PM.StandardACPForm, c_sys5, time_range; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 624
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 96
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = true)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalUnitCommitment, PM.StandardACPForm, c_sys5, time_range; parameters = true);
    @test (:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 624
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 96
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    #14-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalUnitCommitment, PM.StandardACPForm, c_sys14, time_range; parameters = false);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end  
    for con in uc_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range; parameters = true)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalUnitCommitment, PM.StandardACPForm, c_sys14, time_range; parameters = true);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 600
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    for variable in variable_names
        for v in ps_model.variables[variable]
            @test is_binary(v)
        end
    end  
    for con in uc_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef}
end

@testset "Dispatch With DC - PF" begin
    #5-Bus testing    
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatch, PM.DCPlosslessForm, c_sys5, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatch, PM.DCPlosslessForm, c_sys5, time_range; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    #14-Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatch, PM.DCPlosslessForm, c_sys14, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatch, PM.DCPlosslessForm, c_sys14, time_range; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef}   
end

@testset "Dispatch With AC - PF" begin
    #5 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatch, PM.StandardACPForm, c_sys5, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatch, PM.StandardACPForm, c_sys5, time_range; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    #14 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatch, PM.StandardACPForm, c_sys14, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef}  

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatch, PM.StandardACPForm, c_sys14, time_range; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef} 
end

@testset "Dispatch No-Minimum With DC - PF" begin
    #5 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatchNoMin, PM.DCPlosslessForm, c_sys5, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:thermal_active_range]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}


    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatchNoMin, PM.DCPlosslessForm, c_sys5, time_range; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:thermal_active_range]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    #14 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatchNoMin, PM.DCPlosslessForm, c_sys14, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:thermal_active_range]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef} 


    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatchNoMin, PM.DCPlosslessForm, c_sys14, time_range; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:thermal_active_range]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef} 
end

@testset "Dispatch No-Minimum With AC - PF" begin
    #5 Bus testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatchNoMin, PM.StandardACPForm, c_sys5, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:thermal_active_range]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatchNoMin, PM.StandardACPForm, c_sys5, time_range; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:thermal_active_range]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    #14 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatchNoMin, PM.StandardACPForm, c_sys14, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:thermal_active_range]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef} 

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalDispatchNoMin, PM.StandardACPForm, c_sys14, time_range; parameters = false);
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ps_model.constraints[:thermal_active_range]
        @test JuMP.constraint_object(con).set.lower == 0.0
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef} 
end

@testset "Ramp Limited Dispatch With AC - PF" begin
    ramp_constraint_names = [:ramp_thermal_up, :ramp_thermal_down]
    #5 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalRampLimited, PM.StandardACPForm, c_sys5, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalRampLimited, PM.StandardACPForm, c_sys5, time_range; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    #14 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalRampLimited, PM.StandardACPForm, c_sys14, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalRampLimited, PM.StandardACPForm, c_sys14, time_range; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 240
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef}
end

@testset "Ramp Limited Dispatch With DC - PF" begin
    ramp_constraint_names = [:ramp_thermal_up, :ramp_thermal_down]
    #5 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalRampLimited, PM.DCPlosslessForm, c_sys5, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test !isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers5, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalRampLimited, PM.DCPlosslessForm, c_sys5, time_range; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 192
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test !isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericAffExpr{Float64,VariableRef}

    #14 Bus Testing
    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalRampLimited, PM.DCPlosslessForm, c_sys14, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef}

    ps_model = PSI._canonical_model_init(bus_numbers14, nothing, PM.AbstractPowerFormulation, time_range; parameters = false)
    PSI.construct_device!(ps_model, PSY.ThermalDispatch, PSI.ThermalRampLimited, PM.DCPlosslessForm, c_sys14, time_range; parameters = false)
    @test !(:params in keys(ps_model.JuMPmodel.ext))
    @test JuMP.num_variables(ps_model.JuMPmodel) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    for con in ramp_constraint_names
        @test isnothing(get(ps_model.constraints, con, nothing))
    end
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    @test JuMP.objective_function_type(ps_model.JuMPmodel) == GenericQuadExpr{Float64,VariableRef}
end
