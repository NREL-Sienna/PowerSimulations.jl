
""" "Each Tuple corresponds to (con_name, internal_index, moi_index)"""
function get_all_constraint_index(op_problem::OperationsProblem)
    con_index = Vector{Tuple{Symbol, Int64, Int64}}()
    for (key, value) in op_problem.canonical.constraints
        for (idx, constraint) in enumerate(value)
            moi_index = JuMP.optimizer_index(constraint);
            push!(con_index, (key, idx, moi_index.value))
        end
    end

    return con_index
end

""" "Each Tuple corresponds to (con_name, internal_index, moi_index)"""
function get_all_var_index(op_problem::OperationsProblem)
    var_index = Vector{Tuple{Symbol, Int64, Int64}}()
    for (key, value) in op_problem.canonical.variables
        for (idx, variable) in enumerate(value)
            moi_index = JuMP.optimizer_index(variable);
            push!(var_index, (key, idx, moi_index.value))
        end
    end

    return var_index
end

function get_con_index(op_problem::OperationsProblem, index::Int64)

    for i in get_all_constraint_index(op_problem::OperationsProblem)
        if i[3] == index
            return op_problem.canonical.constraints[i[1]].data[i[2]]
        end
    end

    @info "Index not found"

    return

end

function get_var_index(op_problem::OperationsProblem, index::Int64)

    for i in get_all_var_index(op_problem::OperationsProblem)
        if i[3] == index
            return op_problem.canonical.variables[i[1]].data[i[2]]
        end
    end

    @info "Index not found"

    return

end
