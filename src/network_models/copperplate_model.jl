function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    sys::U,
    ::NetworkModel{T},
    S::Type{CopperPlatePowerModel},
) where {T <: Union{CopperPlateBalanceConstraint, StandardPTDFModel}, U <: PSY.System}
    time_steps = get_time_steps(container)
    expressions = get_expression(container, ActivePowerBalance, PSY.System)
    remove_undef!(expressions)
    constraint = add_cons_container!(container, T(), PSY.System, time_steps)
    for t in time_steps
        constraint[t] = JuMP.@constraint(container.JuMPmodel, expressions[t] == 0)
    end

    return
end
