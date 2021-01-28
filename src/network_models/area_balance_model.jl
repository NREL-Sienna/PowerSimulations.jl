function area_balance(
    optimization_container::OptimizationContainer,
    expression::Symbol,
    area_mapping::Dict{String, Array{PSY.Bus, 1}},
    branches,
)
    time_steps = model_time_steps(optimization_container)
    remove_undef!(optimization_container.expressions[expression])
    nodal_net_balance = optimization_container.expressions[expression]
    constraint_bal = JuMPConstraintArray(undef, keys(area_mapping), time_steps)
    participation_assignment_up = JuMPConstraintArray(undef, keys(area_mapping), time_steps)
    participation_assignment_dn = JuMPConstraintArray(undef, keys(area_mapping), time_steps)
    assign_constraint!(optimization_container, "area_dispatch_balance", constraint_bal)
    area_balance = get_variable(optimization_container, ActivePowerVariable, PSY.Area)
    for (k, buses_in_area) in area_mapping
        for t in time_steps
            area_net =
                model_has_parameters(optimization_container) ? zero(PGAE) :
                JuMP.AffExpr(0.0)
            for b in buses_in_area
                JuMP.add_to_expression!(area_net, nodal_net_balance[PSY.get_number(b), t])
            end
            constraint_bal[k, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                area_balance[k, t] == area_net
            )
        end
    end

    expr_up = get_expression(optimization_container, :emergency_up)
    expr_dn = get_expression(optimization_container, :emergency_dn)

    assign_constraint!(
        optimization_container,
        "participation_assignment_up",
        participation_assignment_up,
    )
    assign_constraint!(
        optimization_container,
        "participation_assignment_dn",
        participation_assignment_dn,
    )

    for area in keys(area_mapping), t in time_steps
        participation_assignment_up[area, t] =
            JuMP.@constraint(optimization_container.JuMPmodel, expr_up[area, t] == 0)
        participation_assignment_dn[area, t] =
            JuMP.@constraint(optimization_container.JuMPmodel, expr_dn[area, t] == 0)
    end

    return
end
