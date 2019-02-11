function add_to_cost!(m::JuMP.AbstractModel, cost_expression::Union{JuMP.GenericAffExpr{Float64,V}, JuMP.GenericQuadExpr}) where V <: JuMP.AbstractVariableRef

    obj_dict = JuMP.object_dictionary(m)
    if haskey(obj_dict, :objective_function)

        var_type = JuMP.variable_type(m)
        if (isa(obj_dict[:objective_function],JuMP.GenericAffExpr{Float64,var_type}) && isa(cost_expression,JuMP.GenericAffExpr{Float64,var_type}))

            JuMP.add_to_expression!(obj_dict[:objective_function],cost_expression)

        elseif (isa(obj_dict[:objective_function],JuMP.GenericQuadExpr) && isa(cost_expression,JuMP.GenericQuadExpr))

            JuMP.add_to_expression!(obj_dict[:objective_function],cost_expression)

        else

            obj_dict[:objective_function] += cost_expression

        end

    else

        obj_dict[:objective_function] = cost_expression

    end

end
