function add_constraints!(
    container::OptimizationContainer,
    ::Type{CopperPlateBalanceConstraint},
    sys::PSY.System,
    model::NetworkModel{AreaBalancePowerModel},
)
    time_steps = get_time_steps(container)
    area_names = PSY.get_name.(get_available_components(model, PSY.Area, sys))
    constraint = add_constraints_container!(
        container,
        CopperPlateBalanceConstraint(),
        PSY.Area,
        area_names,
        time_steps,
    )

    area_balance_expr = get_variable(container, ActivePowerVariable(), PSY.Area)
    for area in area_names, t in time_steps
        constraint[area, t] =
            JuMP.@constraint(get_jump_model(container), area_balance_expr[area, t] == 0.0)
    end

    return
end

function agc_area_balance(
    container::OptimizationContainer,
    expression::ExpressionKey,
    area_mapping::Dict{String, Array{PSY.ACBus, 1}},
    branches,
)
    time_steps = get_time_steps(container)
    nodal_net_balance = get_expression(container, expression)

    constraint = add_constraints_container!(
        container,
        CopperPlateBalanceConstraint(),
        PSY.Area,
        keys(area_mapping),
        time_steps,
    )
    area_balance = get_variable(container, ActivePowerVariable(), PSY.Area)
    for (k, buses_in_area) in area_mapping
        for t in time_steps
            area_net = JuMP.AffExpr(0.0)
            for b in buses_in_area
                JuMP.add_to_expression!(area_net, nodal_net_balance[PSY.get_number(b), t])
            end
            constraint[k, t] =
                JuMP.@constraint(get_jump_model(container), area_balance[k, t] == area_net)
        end
    end

    expr_up = get_expression(container, EmergencyUp(), PSY.Area)
    expr_dn = get_expression(container, EmergencyDown(), PSY.Area)

    participation_assignment_up = add_constraints_container!(
        container,
        AreaParticipationAssignmentConstraint(),
        PSY.Area,
        keys(area_mapping),
        time_steps;
        meta = "up",
    )
    participation_assignment_dn = add_constraints_container!(
        container,
        AreaParticipationAssignmentConstraint(),
        PSY.Area,
        keys(area_mapping),
        time_steps;
        meta = "dn",
    )

    for area in keys(area_mapping), t in time_steps
        participation_assignment_up[area, t] =
            JuMP.@constraint(get_jump_model(container), expr_up[area, t] == 0)
        participation_assignment_dn[area, t] =
            JuMP.@constraint(get_jump_model(container), expr_dn[area, t] == 0)
    end

    return
end
