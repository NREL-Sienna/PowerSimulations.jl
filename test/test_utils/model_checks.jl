const GAEVF = JuMP.GenericAffExpr{Float64, VariableRef}
const GQEVF = JuMP.GenericQuadExpr{Float64, VariableRef}

function moi_tests(
    op_problem::OperationsProblem,
    params::Bool,
    vars::Int,
    interval::Int,
    lessthan::Int,
    greaterthan::Int,
    equalto::Int,
    binary::Bool,
)
    JuMPmodel = PSI.get_jump_model(op_problem)
    @test (:ParameterJuMP in keys(JuMPmodel.ext)) == params
    @test JuMP.num_variables(JuMPmodel) == vars
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.Interval{Float64}) == interval
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.LessThan{Float64}) == lessthan
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.GreaterThan{Float64}) == greaterthan
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.EqualTo{Float64}) == equalto
    @test ((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(JuMPmodel)) ==
          binary

    return
end

function psi_constraint_test(
    op_problem::OperationsProblem,
    constraint_names::Vector{Symbol},
)
    constraints = PSI.get_constraints(op_problem)
    for con in constraint_names
        @test !isnothing(get(constraints, con, nothing))
    end
    return
end

function psi_checkbinvar_test(
    op_problem::OperationsProblem,
    bin_variable_names::Vector{Symbol},
)
    container = PSI.get_optimization_container(op_problem)
    for variable in bin_variable_names
        for v in PSI.get_variable(container, variable)
            @test JuMP.is_binary(v)
        end
    end
    return
end

function psi_checkobjfun_test(op_problem::OperationsProblem, exp_type)
    model = PSI.get_jump_model(op_problem)
    @test JuMP.objective_function_type(model) == exp_type
    return
end

function moi_lbvalue_test(op_problem::OperationsProblem, con_name::Symbol, value::Number)
    for con in PSI.get_constraints(op_problem)[con_name]
        @test JuMP.constraint_object(con).set.lower == value
    end
    return
end

function psi_checksolve_test(op_problem::OperationsProblem, status)
    model = PSI.get_jump_model(op_problem)
    JuMP.optimize!(model)
    @test termination_status(model) in status
end

function psi_checksolve_test(
    op_problem::OperationsProblem,
    status,
    expected_result,
    tol = 0.0,
)
    res = solve!(op_problem)
    model = PSI.get_jump_model(op_problem)
    @test termination_status(model) in status
    obj_value = JuMP.objective_value(model)
    @test isapprox(obj_value, expected_result, atol = tol)
end

function psi_ptdf_lmps(op_problem::OperationsProblem, ptdf)
    res = solve!(op_problem)
    λ = convert(Array, res.dual_values[:CopperPlateBalance])
    μ = convert(Array, res.dual_values[:network_flow__Line]) #TODO: should this collect all branch network flows
    buses = get_components(Bus, op_problem.sys)
    lmps = OrderedDict()
    for bus in buses
        lmps[get_name(bus)] = μ * ptdf[:, get_number(bus)]
    end
    lmps = DataFrame(lmps)
    lmps = λ .- lmps
    return lmps[!, sort(propertynames(lmps))]
end

function check_variable_unbounded(op_problem::OperationsProblem, var_name)
    psi_cont = PSI.get_optimization_container(op_problem)
    variable = PSI.get_variable(psi_cont, var_name)
    for var in variable
        if JuMP.has_lower_bound(var) || JuMP.has_upper_bound(var)
            return false
        end
    end
    return true
end

function check_variable_bounded(op_problem::OperationsProblem, var_name)
    psi_cont = PSI.get_optimization_container(op_problem)
    variable = PSI.get_variable(psi_cont, var_name)
    for var in variable
        if !JuMP.has_lower_bound(var) || !JuMP.has_upper_bound(var)
            return false
        end
    end
    return true
end

function check_flow_variable_values(
    op_problem::OperationsProblem,
    var_name::Symbol,
    device_name::String,
    limit::Float64,
)
    psi_cont = PSI.get_optimization_container(op_problem)
    variable = PSI.get_variable(psi_cont, var_name)
    for var in variable[device_name, :]
        if !(JuMP.value(var) <= (limit + 1e-2))
            return false
        end
    end
    return true
end

function check_flow_variable_values(
    op_problem::OperationsProblem,
    var_name::Symbol,
    device_name::String,
    limit_min::Float64,
    limit_max::Float64,
)
    psi_cont = PSI.get_optimization_container(op_problem)
    variable = PSI.get_variable(psi_cont, var_name)
    for var in variable[device_name, :]
        if !(JuMP.value(var) <= (limit_max + 1e-2)) ||
           !(JuMP.value(var) >= (limit_min - 1e-2))
            return false
        end
    end
    return true
end

function check_flow_variable_values(
    op_problem::OperationsProblem,
    pvar_name::Symbol,
    qvar_name::Symbol,
    device_name::String,
    limit_min::Float64,
    limit_max::Float64,
)
    psi_cont = PSI.get_optimization_container(op_problem)
    time_steps = PSI.model_time_steps(psi_cont)
    pvariable = PSI.get_variable(psi_cont, pvar_name)
    qvariable = PSI.get_variable(psi_cont, qvar_name)
    for t in time_steps
        fp = JuMP.value(pvariable[device_name, t])
        fq = JuMP.value(qvariable[device_name, t])
        flow = sqrt((fp)^2 + (fq)^2)
        if !(flow <= (limit_max + 1e-2)^2) || !(flow >= (limit_min - 1e-2)^2)
            return false
        end
    end
    return true
end

function check_flow_variable_values(
    op_problem::OperationsProblem,
    pvar_name::Symbol,
    qvar_name::Symbol,
    device_name::String,
    limit::Float64,
)
    psi_cont = PSI.get_optimization_container(op_problem)
    time_steps = PSI.model_time_steps(psi_cont)
    pvariable = PSI.get_variable(psi_cont, pvar_name)
    qvariable = PSI.get_variable(psi_cont, qvar_name)
    for t in time_steps
        fp = JuMP.value(pvariable[device_name, t])
        fq = JuMP.value(qvariable[device_name, t])
        flow = sqrt((fp)^2 + (fq)^2)
        if !(flow <= (limit + 1e-2)^2)
            return false
        end
    end
    return true
end

function PSI._jump_value(int::Int)
    @warn("This is for testing purposes only.")
    return int
end

function _test_plain_print_methods(list::Array)
    for object in list
        normal = repr(object)
        io = IOBuffer()
        show(io, "text/plain", object)
        grabbed = String(take!(io))
        @test !isnothing(grabbed)
    end
end

function _test_html_print_methods(list::Array)
    for object in list
        normal = repr(object)
        io = IOBuffer()
        show(io, "text/html", object)
        grabbed = String(take!(io))
        @test !isnothing(grabbed)
    end
end
