get_variable_multiplier(::SystemBalanceSlackUp, ::PSY.System, _) = 1.0
get_variable_multiplier(::SystemBalanceSlackDown, ::PSY.System, _) = -1.0

function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    ::PSY.System,
    ::Type{U},
) where {
    T <: Union{SystemBalanceSlackUp, SystemBalanceSlackDown},
    U <: Union{CopperPlatePowerModel, StandardPTDFModel},
}
    time_steps = get_time_steps(container)
    variable = add_var_container!(container, T(), PSY.StaticInjection, time_steps)

    for t in time_steps
        variable[t] =
            JuMP.@variable(container.JuMPmodel, base_name = "$(T)_{$t}", lower_bound = 0.0)
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    ::PSY.System,
    ::NetworkModel{W},
    ::Type{W},
) where {
    T <: SystemBalanceExpressions,
    U <: Union{SystemBalanceSlackUp, SystemBalanceSlackDown},
    W <: Union{CopperPlatePowerModel, StandardPTDFModel},
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.System)
    for t in get_time_steps(container)
        add_to_jump_expression!(
            expression,
            1.0,
            t,
            variable[t],
            get_variable_multiplier(U(), V, W()),
        )
    end
    return
end

function cost_function!(
    container,
    ::PSY.System,
    model::NetworkModel{T},
    S::Type{T},
) where {T <: Union{CopperPlatePowerModel, StandardPTDFModel}}
    variable_up = get_variable(container, SystemBalanceSlackUp())
    variable_dn = get_variable(container, SystemBalanceSlackDown())

    for t in get_time_steps(container)
        add_to_cost_function!(
            container,
            (variable_dn[t] + variable_up[t]) * BALANCE_SLACK_COST,
        )
    end
    return
end
