function add_to_cost!(m::JuMP.Model, cost_expression::Union{JuMP.JuMP.AffExpr, JuMP.JuMP.GenericQuadExpr})
    
    if haskey(m.obj_dict, :objective_function) 
        
        (isa(m.obj_dict[:objective_function],JuMP.AffExpr) && isa(cost_expression,JuMP.AffExpr)) ? JuMP.add_to_expression!(m.obj_dict[:objective_function],cost_expression) : (isa( m.obj_dict[:objective_function],JuMP.GenericQuadExpr) && isa(cost_expression,JuMP.GenericQuadExpr) ? JuMP.add_to_expression!( m.obj_dict[:objective_function],cost_expression) :  m.obj_dict[:objective_function] += cost_expression)
        
    else 

        m.obj_dict[:objective_function] = cost_expression

    end
end