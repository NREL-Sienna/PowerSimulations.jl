function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    sys::U,
    model::NetworkModel{V},
) where {
    T <: CopperPlateBalanceConstraint,
    U <: PSY.System,
    V <: Union{CopperPlatePowerModel, PTDFPowerModel},
}
    time_steps = get_time_steps(container)
    expressions = get_expression(container, ActivePowerBalance(), U)
    subnets = collect(keys(model.subnetworks))
    constraint = add_constraints_container!(container, T(), U, subnets, time_steps)
    for t in time_steps, k in keys(model.subnetworks)
        constraint[k, t] =
            JuMP.@constraint(get_jump_model(container), expressions[k, t] == 0)
    end

    return
end
