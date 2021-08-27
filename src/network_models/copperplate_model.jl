function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    sys::U,
    ::NetworkModel{V},
    S::Type{V},
) where {
    T <: CopperPlateBalanceConstraint,
    U <: PSY.System,
    V <: Union{CopperPlatePowerModel, StandardPTDFModel},
}
    time_steps = get_time_steps(container)
    expressions = get_expression(container, ActivePowerBalance(), U)
    remove_undef!(expressions)
    constraint = add_cons_container!(container, T(), U, time_steps)
    for t in time_steps
        constraint[t] = JuMP.@constraint(container.JuMPmodel, expressions[t] == 0)
    end

    return
end
