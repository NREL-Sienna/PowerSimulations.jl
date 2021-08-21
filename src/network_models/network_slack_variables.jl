function _add_system_balance_slacks!(
    container::OptimizationContainer,
    expression::Symbol,
    single_first_axes::Bool = false,
)
    time_steps = get_time_steps(container)
    expression_array = get_expression(container, expression)
    single_first_axes && (first_index = [axes(expression_array)[1][1]])
    !single_first_axes && (first_index = axes(expression_array)[1])
    variable_up = add_var_container!(
        container,
        SystemBalanceSlackUp(),
        PSY.StaticInjection,
        first_index,
        time_steps,
    )
    variable_dn = add_var_container!(
        container,
        SystemBalanceSlackDown(),
        PSY.StaticInjection,
        first_index,
        time_steps,
    )
    for ix in first_index, jx in time_steps
        variable_up[ix, jx] = JuMP.@variable(
            container.JuMPmodel,
            base_name = "$(var_name_up)_{$(ix), $(jx)}",
            lower_bound = 0.0
        )
        variable_dn[ix, jx] = JuMP.@variable(
            container.JuMPmodel,
            base_name = "$(var_name_dn)_{$(ix), $(jx)}",
            lower_bound = 0.0
        )
        add_to_expression!(expression_array, ix, jx, variable_up[ix, jx], 1.0)
        add_to_expression!(expression_array, ix, jx, variable_dn[ix, jx], -1.0)
        JuMP.add_to_expression!(
            container.cost_function,
            (variable_dn[ix, jx] + variable_up[ix, jx]) * BALANCE_SLACK_COST,
        )
    end
    return
end

function add_slacks!(container::OptimizationContainer, ::Type{CopperPlatePowerModel})
    _add_system_balance_slacks!(container, :nodal_balance_active, true)
    return
end

function add_slacks!(
    container::OptimizationContainer,
    ::Type{T},
) where {T <: PM.AbstractActivePowerModel}
    _add_system_balance_slacks!(container, :nodal_balance_active)
    return
end

function add_slacks!(
    container::OptimizationContainer,
    ::Type{T},
) where {T <: PM.AbstractPowerModel}
    _add_system_balance_slacks!(container, :nodal_balance_active)
    # TODO: Enable later
    #_add_system_balance_slacks!(container, :nodal_balance_reactive)
    return
end
