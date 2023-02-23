function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    sys::U,
    ::NetworkModel{V},
) where {
    T <: CopperPlateBalanceConstraint,
    U <: PSY.System,
    V <: Union{CopperPlatePowerModel, StandardPTDFModel, PTDFPowerModel},
}
    time_steps = get_time_steps(container)
    expressions = get_expression(container, ActivePowerBalance(), U)
    constraint = add_constraints_container!(container, T(), U, time_steps)
    for t in time_steps
        constraint[t] = JuMP.@constraint(get_jump_model(container), expressions[t] == 0)
    end

    return
end
