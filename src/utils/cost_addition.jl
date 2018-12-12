function add_to_cost!(m::JuMP.AbstractModel, cost_expression::Union{JuMP.JuMP.AffExpr, JuMP.JuMP.GenericQuadExpr})

    if haskey(m.obj_dict, :objective_function)

        if (isa(m.obj_dict[:objective_function],JuMP.AffExpr) && isa(cost_expression,JuMP.AffExpr))

            JuMP.add_to_expression!(m.obj_dict[:objective_function],cost_expression)

        elseif (isa( m.obj_dict[:objective_function],JuMP.GenericQuadExpr) && isa(cost_expression,JuMP.GenericQuadExpr))

            JuMP.add_to_expression!(m.obj_dict[:objective_function],cost_expression)

        else

            m.obj_dict[:objective_function] += cost_expression

        end

    else

        m.obj_dict[:objective_function] = cost_expression

    end

end
