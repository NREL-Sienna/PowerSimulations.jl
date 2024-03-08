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
function get_all_variable_index(model::OperationModel)
    var_keys = get_all_variable_keys(model)
    return [(encode_key(v[1]), v[2], v[3]) for v in var_keys]
end

function get_all_variable_keys(model::OperationModel)
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

function get_constraint_index(model::OperationModel, index::Int)
    container = get_optimization_container(model)
    constraints = get_constraints(container)
    for i in get_all_constraint_index(model)
        if i[3] == index
            return constraints[i[1]].data[i[2]]
        end
    end
    @info "Index not found"
    return
end

function get_variable_index(model::OperationModel, index::Int)
    container = get_optimization_container(model)
    variables = get_variables(container)
    for i in get_all_variable_keys(model)
        if i[3] == index
            return variables[i[1]].data[i[2]]
        end
    end
    @info "Index not found"
    return
end

function get_detailed_constraint_numerical_bounds(model::OperationModel)
    if !is_built(model)
        error("Model not built, can't calculate constraint numerical bounds")
    end
    constraint_bounds = Dict()
    for (const_key, constraint_array) in get_constraints(get_optimization_container(model))
        if isa(constraint_array, SparseAxisArray)
            bounds = ConstraintBounds()
            for idx in eachindex(constraint_array)
                constraint_array[idx] == 0.0 && continue
                con_obj = JuMP.constraint_object(constraint_array[idx])
                update_coefficient_bounds(bounds, con_obj, idx)
                update_rhs_bounds(bounds, con_obj, idx)
            end
            constraint_bounds[const_key] = bounds
        else
            bounds = ConstraintBounds()
            for idx in Iterators.product(constraint_array.axes...)
                con_obj = JuMP.constraint_object(constraint_array[idx...])
                update_coefficient_bounds(bounds, con_obj, idx)
                update_rhs_bounds(bounds, con_obj, idx)
            end
            constraint_bounds[const_key] = bounds
        end
    end
    return constraint_bounds
end

function get_detailed_variable_numerical_bounds(model::OperationModel)
    if !is_built(model)
        error("Model not built, can't calculate variable numerical bounds")
    end
    variable_bounds = Dict()
    for (variable_key, variable_array) in get_variables(get_optimization_container(model))
        bounds = VariableBounds()
        if isa(variable_array, SparseAxisArray)
            for idx in eachindex(variable_array)
                var = variable_array[idx]
                var == 0.0 && continue
                update_variable_bounds(bounds, var, idx)
            end
        else
            for idx in Iterators.product(variable_array.axes...)
                var = variable_array[idx...]
                update_variable_bounds(bounds, var, idx)
            end
        end
        variable_bounds[variable_key] = bounds
    end
    return variable_bounds
end
