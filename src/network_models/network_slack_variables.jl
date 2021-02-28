function _add_system_balance_slacks!(
    optimization_container::OptimizationContainer,
    slack_name::String,
    expression::Symbol,
    single_first_axes::Bool = false,
)
    time_steps = model_time_steps(optimization_container)
    expression_array = get_expression(optimization_container, expression)
    var_name_up = make_variable_name(slack_name, SLACK_UP)
    var_name_dn = make_variable_name(slack_name, SLACK_DN)
    single_first_axes && (first_index = [axes(expression_array)[1][1]])
    !single_first_axes && (first_index = axes(expression_array)[1])
    variable_up =
        add_var_container!(optimization_container, var_name_up, first_index, time_steps)
    variable_dn =
        add_var_container!(optimization_container, var_name_dn, first_index, time_steps)
    for ix in first_index, jx in time_steps
        variable_up[ix, jx] = JuMP.@variable(
            optimization_container.JuMPmodel,
            base_name = "$(var_name_up)_{$(ix), $(jx)}",
            lower_bound = 0.0
        )
        variable_dn[ix, jx] = JuMP.@variable(
            optimization_container.JuMPmodel,
            base_name = "$(var_name_dn)_{$(ix), $(jx)}",
            lower_bound = 0.0
        )
        axs = typeof(optimization_container.pm) == CopperPlatePowerModel ? jx : (ix, jx)
        add_to_expression!(expression_array, variable_up[ix, jx], 1.0, axs...)
        add_to_expression!(expression_array, variable_dn[ix, jx], -1.0, axs...)
        JuMP.add_to_expression!(
            optimization_container.cost_function,
            (variable_dn[ix, jx] + variable_up[ix, jx]) * BALANCE_SLACK_COST,
        )
    end
    return
end

function add_slacks!(
    optimization_container::OptimizationContainer,
    ::Type{CopperPlatePowerModel},
)
    _add_system_balance_slacks!(
        optimization_container,
        ACTIVE_POWER,
        :system_balance_active,
        true,
    )
    return
end

function add_slacks!(
    optimization_container::OptimizationContainer,
    ::Type{T},
) where {T <: PM.AbstractActivePowerModel}
    _add_system_balance_slacks!(optimization_container, ACTIVE_POWER, :nodal_balance_active)
    return
end

function add_slacks!(
    optimization_container::OptimizationContainer,
    ::Type{T},
) where {T <: PM.AbstractPowerModel}
    _add_system_balance_slacks!(optimization_container, ACTIVE_POWER, :nodal_balance_active)
    _add_system_balance_slacks!(
        optimization_container,
        REACTIVE_POWER,
        :nodal_balance_reactive,
    )
    return
end
