function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    sys::U,
    model::NetworkModel{V},
) where {
    T <: CopperPlateBalanceConstraint,
    U <: PSY.System,
    V <: Union{CopperPlatePowerModel, PTDFPowerModel, SecurityConstrainedPTDFPowerModel},
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

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    sys::U,
    network_model::NetworkModel{V},
) where {
    T <: CopperPlateBalanceConstraint,
    U <: PSY.System,
    V <: Union{AreaPTDFPowerModel, SecurityConstrainedAreaPTDFPowerModel},
}
    time_steps = get_time_steps(container)
    expressions = get_expression(container, ActivePowerBalance(), PSY.Area)
    area_names = PSY.get_name.(get_available_components(network_model, PSY.Area, sys))
    constraint =
        add_constraints_container!(container, T(), PSY.Area, area_names, time_steps)
    jm = get_jump_model(container)
    for t in time_steps, k in area_names
        constraint[k, t] = JuMP.@constraint(jm, expressions[k, t] == 0)
    end

    return
end
