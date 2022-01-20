"""
Replaces an expression value in the expression container if the key exists
"""
function set_expression!(
    container::OptimizationContainer,
    ::Type{S},
    cost_expression::JuMP.AbstractJuMPScalar,
    component::T,
    time_period::Int,
) where {S <: CostExpressions, T <: PSY.Component}
    if has_container_key(container, S, T)
        device_cost_expression = get_expression(container, S(), T)
        component_name = PSY.get_name(component)
        device_cost_expression[component_name, time_period] = cost_expression
    end
    return
end
