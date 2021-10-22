function automated_construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, U},
    ::Type{V};
    parameters = [],
    variables = [],
    constraints = [],
    initial_conditions = [],
    expressions = [],
    to_expressions = [],
    add_initial_conditions = false,
    add_feedforward_arguments = false,
    add_cost_function = false,
    add_constraint_dual = false,
) where {T <: PSY.Component, U <: AbstractDeviceFormulation, V <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    for variable_type in variables
        add_variables!(container, variable_type, devices, U())
    end

    for (expression_type, variable_type) in to_expressions
        add_to_expression!(container, expression_type, variable_type, devices, model, V)
    end

    for expression_type in expressions
        add_expressions!(container, expression_type, devices, model)
    end

    for (constraint_type, expression_type) in constraints
        add_constraints!(container, constraint_type, expression_type, devices, model, V)
    end

    add_initial_conditions && initial_conditions!(container, devices, U())
    add_cost_function && cost_function!(container, devices, model, T)
    add_constraint_dual && add_constraint_dual!(container, sys, model)
    add_feedforward_arguments && add_feedforward_arguments!(container, model, devices)
end
