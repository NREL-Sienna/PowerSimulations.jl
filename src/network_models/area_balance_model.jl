function area_balance(
    psi_container::PSIContainer,
    expression::Symbol,
    area_mapping::Dict{String, Array{PSY.Bus, 1}},
    branches,
)
    time_steps = model_time_steps(psi_container)
    remove_undef!(psi_container.expressions[expression])
    nodal_net_balance = psi_container.expressions[expression]
    constraint_bal = JuMPConstraintArray(undef, keys(area_mapping), time_steps)
    assign_constraint!(psi_container, "area_dispatch_balance", constraint_bal)
    area_balance = get_variable(psi_container, variable_name("area_dispatch_balance"))

    for (k, buses_in_area) in area_mapping
        for t in time_steps
            area_net = JuMP.AffExpr(0.0)
            for b in buses_in_area
                JuMP.add_to_expression!(area_net, nodal_net_balance[PSY.get_number(b), t])
            end
            constraint_bal[k, t] =
                    JuMP.@constraint(psi_container.JuMPmodel, area_balance[k, t] == area_net)
        end
    end
    return
end
