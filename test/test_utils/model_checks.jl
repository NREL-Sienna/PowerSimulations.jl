const GAEVF = JuMP.GenericAffExpr{Float64, VariableRef}
const GQEVF = JuMP.GenericQuadExpr{Float64, VariableRef}

function moi_tests(op_model::OperationModel,
                   params::Bool,
                   vars::Int64,
                   interval::Int64,
                   lessthan::Int64,
                   greaterthan::Int64,
                   equalto::Int64,
                   binary::Bool)

    JuMPmodel = op_model.canonical.JuMPmodel
    @test (:params in keys(JuMPmodel.ext)) == params
    @test JuMP.num_variables(JuMPmodel) == vars
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.Interval{Float64}) == interval
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.LessThan{Float64}) == lessthan
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.GreaterThan{Float64}) == greaterthan
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.EqualTo{Float64}) == equalto
    @test ((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(JuMPmodel)) == binary

    return

end

function psi_constraint_test(op_model::OperationModel, constraint_names::Vector{Symbol})

    for con in constraint_names
        @test !isnothing(get(op_model.canonical.constraints, con, nothing))
    end

    return

end

function psi_checkbinvar_test(op_model::OperationModel, bin_variable_names::Vector{Symbol})

    for variable in bin_variable_names
        for v in op_model.canonical.variables[variable]
            @test JuMP.is_binary(v)
        end
    end

    return

end

function psi_checkobjfun_test(op_model::OperationModel, exp_type)

    @test JuMP.objective_function_type(op_model.canonical.JuMPmodel) == exp_type

    return

end

function moi_ubvalue_test(op_model::OperationModel, con_name::Symbol, value::Number)

    for con in op_model.canonical.constraints[con_name]
        @test JuMP.constraint_object(con).set.lower == value
    end

    return

end

function psi_checksolve_test(op_model::OperationModel, status)
    JuMP.optimize!(op_model.canonical.JuMPmodel)
    @test termination_status(op_model.canonical.JuMPmodel) in status
end