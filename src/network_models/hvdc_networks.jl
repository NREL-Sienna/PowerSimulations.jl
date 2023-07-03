function add_constraints!(
    container::OptimizationContainer,
    ::Type{NodalBalanceActiveConstraint},
    sys::PSY.System,
    model::NetworkModel{V},
) where {V <: PM.AbstractPowerModel}
    dc_buses = PSY.get_components(PSY.DCBus, sys)
    if isempty(dc_buses)
        return
    end

    time_steps = get_time_steps(container)
    dc_expr = get_expression(container, ActivePowerBalance(), PSY.DCBus)
    balance_constraint = add_constraints_container!(
        container,
        NodalBalanceActiveConstraint(),
        PSY.DCBus,
        axes(dc_expr)[1],
        time_steps,
    )
    for d in dc_buses
        dc_bus_no = PSY.get_number(d)
        for t in time_steps
            balance_constraint[dc_bus_no, t] =
                JuMP.@constraint(get_jump_model(container), dc_expr[dc_bus_no, t] == 0)
        end
    end
    return
end
