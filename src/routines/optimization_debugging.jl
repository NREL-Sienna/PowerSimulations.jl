function get_constraint_index(op_model::OperationModel)
    con_index = Vector{Tuple{Symbol, Int64, Int64}}()
    for (key,value) in op_model.canonical_model.constraints
        for (idx,constraint) in enumerate(value)
            moi_index = JuMP.optimizer_index(constraint);
            push!(con_index,(key, idx, moi_index.value))
        end
    end
    return con_index
end