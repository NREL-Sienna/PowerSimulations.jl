"""
Each Tuple corresponds to (con_name, internal_index, moi_index)
"""
function get_all_constraint_index(model::OperationModel)
    con_index = Vector{Tuple{ConstraintKey, Int, Int}}()
    container = get_optimization_container(model)
    for (key, value) in get_constraints(container)
        for (idx, constraint) in enumerate(value)
            moi_index = JuMP.optimizer_index(constraint)
            push!(con_index, (key, idx, moi_index.value))
        end
    end
    return con_index
end

"""
Each Tuple corresponds to (con_name, internal_index, moi_index)
"""
function get_all_var_index(model::OperationModel)
    var_keys = get_all_var_keys(model)
    return [(encode_key(v[1]), v[2], v[3]) for v in var_keys]
end

function get_all_var_keys(model::OperationModel)
    var_index = Vector{Tuple{VariableKey, Int, Int}}()
    container = get_optimization_container(model)
    for (key, value) in get_variables(container)
        for (idx, variable) in enumerate(value)
            moi_index = JuMP.optimizer_index(variable)
            push!(var_index, (key, idx, moi_index.value))
        end
    end
    return var_index
end

function get_con_index(model::OperationModel, index::Int)
    container = get_optimization_container(model)
    constraints = get_constraints(container)
    for i in get_all_constraint_index(model::OperationModel)
        if i[3] == index
            return constraints[i[1]].data[i[2]]
        end
    end
    @info "Index not found"
    return
end

function get_var_index(model::OperationModel, index::Int)
    container = get_optimization_container(model)
    variables = get_variables(container)
    for i in get_all_var_keys(model)
        if i[3] == index
            return variables[i[1]].data[i[2]]
        end
    end
    @info "Index not found"
    return
end
