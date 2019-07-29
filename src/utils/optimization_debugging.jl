function get_constraint_index(op_model::OperationModel)
    con_index = Vector{Tuple{Symbol, Int64, Int64}}()
    for (key, value) in op_model.canonical.constraints
        for (idx, constraint) in enumerate(value)
            moi_index = JuMP.optimizer_index(constraint);
            push!(con_index, (key, idx, moi_index.value))
        end
    end
    @info "Each Tuple corresponds to (con_name, internal_index, moi_index)"
    return con_index
end

function get_var_index(op_model::OperationModel)
    var_index = Vector{Tuple{Symbol, Int64, Int64}}()
    for (key, value) in op_model.canonical.variables
        for (idx, variable) in enumerate(value)
            moi_index = JuMP.optimizer_index(variable);
            push!(var_index, (key, idx, moi_index.value))
        end
    end
    @info "Each Tuple corresponds to (var_name, internal_index, moi_index)"
    return var_index
end